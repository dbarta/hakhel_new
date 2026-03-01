# frozen_string_literal: true

#
# SMS Pipeline End-to-End Test Script
# =====================================
# Usage:  bin/rails runner 'load Rails.root.join("script","hke","test_sms_pipeline.rb")'
#
# Prerequisites:
#   1. Rails server must be running (bin/dev) — the CSV import uses the API
#   2. The debug phone override in TwilioSend is active (+972584579444)
#   3. System preferences exist (offset includes 1, delivery_priority includes "sms")
#
# What this script does:
#   Step 1: Clean up previous test data (deceased/contacts named "טסטר")
#   Step 2: Import test CSV (2 rows: deceased אברהם טסטר and יצחק טסטר)
#           Both have death date 13 Adar → yahrzeit = Mar 2 → offset 1 → send_date = today
#   Step 3: Verify FutureMessages were created with send_date = today
#   Step 4: Approve Row 1 (אברהם טסטר), leave Row 2 (יצחק טסטר) pending
#   Step 5: Run FutureMessageSendJob synchronously for each
#   Step 6: Verify:
#           - Row 1 → SentMessage (SMS to debug phone +972584579444)
#           - Row 2 → NotSentMessage (reason: not_approved)
#
# NOTE: This script is DATE-SENSITIVE. It only works when today's Hebrew date
# produces the correct yahrzeit alignment. See CSV death dates (13 Adar).
# =====================================

puts "\n#{"=" * 60}"
puts "SMS Pipeline End-to-End Test"
puts "Today: #{Date.current} (#{Time.zone.name})"
puts "#{"=" * 60}\n"

# ---- Step 0: Setup ----
community = Hke::Community.first
unless community
  puts "❌ No community found. Run seeds first."
  exit 1
end
ActsAsTenant.current_tenant = community
puts "✅ Using community: #{community.name} (id: #{community.id})"

# Check system preferences
resolved = Hke::PreferenceResolver.resolve(preferring: community)
puts "   Offsets: #{resolved.how_many_days_before_yahrzeit_to_send_message.inspect}"
puts "   Delivery priority: #{resolved.delivery_priority.inspect}"
puts "   Send window: #{resolved.send_window_start_wall_clock_str || "none"}"

# ---- Step 1: Clean up previous test data ----
puts "\n--- Step 1: Clean up previous test data ---"
test_deceased = Hke::DeceasedPerson.where(last_name: "טסטר")
test_contacts = Hke::ContactPerson.where(last_name: "טסטר")
test_relations = Hke::Relation
  .where(deceased_person: test_deceased)
  .or(Hke::Relation.where(contact_person: test_contacts))

# Delete FutureMessages, Relations, and People — but KEEP SentMessages & NotSentMessages as history
fm_ids = Hke::FutureMessage.where(messageable: test_relations).pluck(:id)
fm_count = Hke::FutureMessage.where(id: fm_ids).delete_all
rel_count = test_relations.delete_all
dp_count = test_deceased.delete_all
cp_count = test_contacts.delete_all
puts "   Cleaned: #{dp_count} deceased, #{cp_count} contacts, #{rel_count} relations, #{fm_count} FMs"
puts "   Kept: #{Hke::SentMessage.count} SMs, #{Hke::NotSentMessage.count} NSMs (history preserved)"

# ---- Step 2: Import test CSV ----
puts "\n--- Step 2: Import test CSV ---"
csv_path = Rails.root.join("db", "data", "hke", "test_sms_pipeline.csv")
unless File.exist?(csv_path)
  puts "❌ Test CSV not found at #{csv_path}"
  exit 1
end

require_relative "support/api_seeds_executor"
executor = ApiSeedsExecutor.new(10)
executor.process_csv(csv_path)

# Find the test records that were just imported
test_deceased = Hke::DeceasedPerson.where(last_name: "טסטר")
test_contacts = Hke::ContactPerson.where(last_name: "טסטר")
test_relations = Hke::Relation
  .where(deceased_person: test_deceased)
  .or(Hke::Relation.where(contact_person: test_contacts))

puts "   Imported: #{test_deceased.count} deceased, #{test_contacts.count} contacts, #{test_relations.count} relations"

test_deceased.each do |dp|
  puts "   → Deceased: #{dp.name} (death: #{dp.hebrew_day_of_death} #{dp.hebrew_month_of_death})"
end
test_contacts.each do |cp|
  puts "   → Contact: #{cp.name} (phone: #{cp.phone})"
end

# ---- Step 3: Verify FutureMessages ----
puts "\n--- Step 3: Verify FutureMessages ---"
today = Date.current
test_fms = Hke::FutureMessage.where(messageable: test_relations)
puts "   Total test FutureMessages: #{test_fms.count}"

test_fms.each do |fm|
  relation = fm.messageable
  dp_name = relation&.deceased_person&.name || "?"
  cp_name = relation&.contact_person&.name || "?"
  puts "   → FM ##{fm.id}: #{dp_name} ↔ #{cp_name}, send_date: #{fm.send_date}, method: #{fm.delivery_method}, approval: #{fm.approval_status}"
end

todays_test_fms = test_fms.where(send_date: today)
if todays_test_fms.empty?
  puts "   ❌ No test FutureMessages for today (#{today}). Check death dates and offsets."
  puts "      Hint: death date should be 13 Adar with offset 1 → send_date = today."
  puts "      All test FM send dates: #{test_fms.pluck(:send_date).inspect}"
  exit 1
end
puts "   ✅ #{todays_test_fms.count} FutureMessages scheduled for today"

# ---- Step 4: Approve one, leave one pending ----
puts "\n--- Step 4: Approve first message, leave second pending ---"
ordered_fms = todays_test_fms.order(:id).to_a
admin_user = User.find_by(admin: true) || User.first

# Approve the first (אברהם טסטר)
fm_to_send = ordered_fms[0]
fm_to_send.approve!(admin_user)
dp_name_1 = fm_to_send.messageable&.deceased_person&.name
puts "   ✅ FM ##{fm_to_send.id} (#{dp_name_1}) → approved"

# Leave the second pending (יצחק טסטר) if exists
if ordered_fms[1]
  fm_pending = ordered_fms[1]
  dp_name_2 = fm_pending.messageable&.deceased_person&.name
  puts "   ⏸  FM ##{fm_pending.id} (#{dp_name_2}) → remains #{fm_pending.approval_status}"
end

# ---- Step 5: Run send jobs ----
puts "\n--- Step 5: Run FutureMessageSendJob (synchronous) ---"
before_sent = Hke::SentMessage.count
before_not_sent = Hke::NotSentMessage.count

# Reload to get the IDs before they get deleted
fm_ids_to_process = todays_test_fms.pluck(:id)
fm_ids_to_process.each do |fm_id|
  fm = Hke::FutureMessage.find_by(id: fm_id)
  next unless fm
  dp_name = fm.messageable&.deceased_person&.name || "?"
  puts "   Running job for FM ##{fm_id} (#{dp_name}, #{fm.approval_status})..."
  begin
    Hke::FutureMessageSendJob.new.perform(fm_id, community.id)
    puts "   ✅ Job completed for FM ##{fm_id}"
  rescue => e
    puts "   ❌ Job failed for FM ##{fm_id}: #{e.message}"
    puts "      #{e.backtrace.first(3).join("\n      ")}"
  end
end

# ---- Step 6: Verify results ----
puts "\n--- Step 6: Verify results ---"
after_sent = Hke::SentMessage.count
after_not_sent = Hke::NotSentMessage.count

new_sent = after_sent - before_sent
new_not_sent = after_not_sent - before_not_sent

puts "   SentMessages: #{before_sent} → #{after_sent} (+#{new_sent})"
puts "   NotSentMessages: #{before_not_sent} → #{after_not_sent} (+#{new_not_sent})"

# Show details of new sent messages
puts "\n   --- Sent Messages ---"
Hke::SentMessage.where(messageable: test_relations).order(created_at: :desc).each do |sm|
  relation = sm.messageable
  dp_name = relation&.deceased_person&.name || "?"
  puts "   📤 Sent ##{sm.id}: #{dp_name}, method=#{sm.delivery_method}, phone=#{sm.phone}, SID=#{sm.twilio_message_sid}"
end

# Show details of new not-sent messages
puts "\n   --- Not-Sent Messages ---"
Hke::NotSentMessage.where(messageable: test_relations).order(created_at: :desc).each do |nsm|
  relation = nsm.messageable
  dp_name = relation&.deceased_person&.name || "?"
  puts "   🚫 NotSent ##{nsm.id}: #{dp_name}, reason=#{nsm.reason}, method=#{nsm.delivery_method}, error=#{nsm.error_message}"
end

# Final summary
puts "\n#{"=" * 60}"
puts "SUMMARY"
puts "  New SentMessages:    #{new_sent} (expected: 1)"
puts "  New NotSentMessages: #{new_not_sent} (expected: 1)"
if new_sent == 1 && new_not_sent == 1
  puts "  ✅ ALL TESTS PASSED"
elsif new_sent == 1
  puts "  ⚠️  SMS delivery succeeded, but not_approved count unexpected"
elsif new_not_sent >= 1 && new_sent == 0
  puts "  ⚠️  No SMS delivered — check Twilio credentials and send window"
else
  puts "  ❌ Unexpected results — investigate"
end
puts "#{"=" * 60}"

ActsAsTenant.current_tenant = nil
puts "\n✅ Test complete.\n"
