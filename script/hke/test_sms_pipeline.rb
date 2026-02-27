# frozen_string_literal: true
#
# SMS Pipeline End-to-End Test Script
# =====================================
# Usage:  bin/rails runner 'load Rails.root.join("script","hke","test_sms_pipeline.rb")'
#
# Prerequisites:
#   1. Rails server must be running (bin/dev) — the CSV import uses the API
#   2. Sidekiq must be running, OR run jobs inline (this script uses perform_inline)
#   3. The debug phone override in TwilioSend is active (+972584579444)
#   4. System preferences exist (offset includes 1, delivery_priority includes "sms")
#
# What this script does:
#   Step 1: Import test CSV (2 rows: deceased אברהם טסטר and יצחק טסטר)
#           Both have death date 11 Adar → yahrzeit = Feb 28 → offset 1 → send_date = today
#   Step 2: Verify FutureMessages were created with send_date = today
#   Step 3: Approve Row 1's message, leave Row 2 pending
#   Step 4: Trigger the community scheduler (synchronous)
#   Step 5: Verify:
#           - Row 1 → SentMessage (SMS to debug phone)
#           - Row 2 → NotSentMessage (reason: not_approved)
#   Step 6: Print summary
#
# NOTE: This script is DATE-SENSITIVE. It only works when today's Hebrew date
# produces the correct yahrzeit alignment. See CSV death dates (11 Adar).
# =====================================

puts "\n#{'=' * 60}"
puts "SMS Pipeline End-to-End Test"
puts "Today: #{Date.current} (#{Time.zone.name})"
puts "#{'=' * 60}\n"

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
puts "   Send window: #{resolved.send_window_start_wall_clock_str || 'none'}"

# ---- Step 1: Import test CSV ----
puts "\n--- Step 1: Import test CSV ---"
csv_path = Rails.root.join("db", "data", "hke", "test_sms_pipeline.csv")
unless File.exist?(csv_path)
  puts "❌ Test CSV not found at #{csv_path}"
  exit 1
end

# Count records before import
before_deceased = Hke::DeceasedPerson.count
before_contacts = Hke::ContactPerson.count
before_relations = Hke::Relation.count
before_future = Hke::FutureMessage.count

require_relative "support/api_seeds_executor"
executor = ApiSeedsExecutor.new(10)
executor.process_csv(csv_path)

after_deceased = Hke::DeceasedPerson.count
after_contacts = Hke::ContactPerson.count
after_relations = Hke::Relation.count
after_future = Hke::FutureMessage.count

puts "   Deceased: #{before_deceased} → #{after_deceased} (+#{after_deceased - before_deceased})"
puts "   Contacts: #{before_contacts} → #{after_contacts} (+#{after_contacts - before_contacts})"
puts "   Relations: #{before_relations} → #{after_relations} (+#{after_relations - before_relations})"
puts "   FutureMessages: #{before_future} → #{after_future} (+#{after_future - before_future})"

# ---- Step 2: Verify FutureMessages ----
puts "\n--- Step 2: Verify FutureMessages with send_date = today ---"
today = Date.current
todays_fms = Hke::FutureMessage.where(send_date: today)
puts "   FutureMessages scheduled for today: #{todays_fms.count}"

todays_fms.each do |fm|
  relation = fm.messageable
  dp_name = relation&.deceased_person&.name || "?"
  cp_name = relation&.contact_person&.name || "?"
  puts "   → FM ##{fm.id}: #{dp_name} ↔ #{cp_name}, method: #{fm.delivery_method}, approval: #{fm.approval_status}"
end

if todays_fms.count < 2
  puts "⚠️  Expected at least 2 FutureMessages for today. Check death dates and offsets."
  puts "   Hint: This script expects deceased with death on 11 Adar and offset including 1."
end

# ---- Step 3: Approve one, leave one pending ----
puts "\n--- Step 3: Approve first message, leave second pending ---"
test_fms = todays_fms.order(:id).last(2)
if test_fms.size >= 2
  # Need a user for approval
  admin_user = User.find_by(admin: true) || User.first
  test_fms[0].approve!(admin_user)
  puts "   ✅ FM ##{test_fms[0].id} → approved"
  puts "   ⏸  FM ##{test_fms[1].id} → remains #{test_fms[1].approval_status}"
elsif test_fms.size == 1
  admin_user = User.find_by(admin: true) || User.first
  test_fms[0].approve!(admin_user)
  puts "   ✅ FM ##{test_fms[0].id} → approved (only 1 found)"
else
  puts "   ❌ No test FutureMessages found for today"
  exit 1
end

# ---- Step 4: Trigger scheduler ----
puts "\n--- Step 4: Trigger community scheduler (synchronous) ---"
before_sent = Hke::SentMessage.count
before_not_sent = Hke::NotSentMessage.count

# Run each job inline instead of async
todays_fms.reload.each do |fm|
  puts "   Running FutureMessageSendJob for FM ##{fm.id}..."
  begin
    Hke::FutureMessageSendJob.new.perform(fm.id, community.id)
    puts "   ✅ Job completed for FM ##{fm.id}"
  rescue => e
    puts "   ❌ Job failed for FM ##{fm.id}: #{e.message}"
  end
end

# ---- Step 5: Verify results ----
puts "\n--- Step 5: Verify results ---"
after_sent = Hke::SentMessage.count
after_not_sent = Hke::NotSentMessage.count

puts "   SentMessages: #{before_sent} → #{after_sent} (+#{after_sent - before_sent})"
puts "   NotSentMessages: #{before_not_sent} → #{after_not_sent} (+#{after_not_sent - before_not_sent})"

# Show recent sent messages
Hke::SentMessage.order(created_at: :desc).limit(3).each do |sm|
  puts "   📤 Sent ##{sm.id}: #{sm.delivery_method} to #{sm.phone}, SID: #{sm.twilio_message_sid}"
end

# Show recent not-sent messages
Hke::NotSentMessage.order(created_at: :desc).limit(3).each do |nsm|
  puts "   🚫 NotSent ##{nsm.id}: reason=#{nsm.reason}, method=#{nsm.delivery_method}, phone=#{nsm.phone}"
end

# ---- Step 6: Summary ----
remaining_fms = Hke::FutureMessage.where(send_date: today).count
puts "\n#{'=' * 60}"
puts "SUMMARY"
puts "  New SentMessages:    #{after_sent - before_sent}"
puts "  New NotSentMessages: #{after_not_sent - before_not_sent}"
puts "  Remaining FMs today: #{remaining_fms}"
puts "  (Remaining FMs should have been recreated for next yahrzeit)"
puts "#{'=' * 60}"

ActsAsTenant.current_tenant = nil
puts "\n✅ Test complete.\n"
