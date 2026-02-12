# frozen_string_literal: true

puts "\n=== HKE Preferences Pipeline Test ==="

def assert(name)
  result = yield
  if result
    puts "PASS: #{name}"
  else
    puts "FAIL: #{name}"
  end
rescue => e
  puts "ERROR: #{name} -> #{e.class}: #{e.message}"
end

r = Hke::Relation.first
abort "No Relation found" unless r
community = r.community
abort "Relation has no community" unless community

ActsAsTenant.current_tenant = community

puts "\nUsing Relation ##{r.id} (Community #{community.id})"
# -------------------------
# regenerate future message
# -------------------------

r.process_future_messages
fm = r.future_messages.first
abort "No FutureMessage generated" unless fm

resolved = Hke::PreferenceResolver.resolve(preferring: r)

# -------------------------
# TEST 1 — single future message
# -------------------------

assert("single FutureMessage per relation") do
  r.future_messages.count == 1
end

# -------------------------
# TEST 2 — offset-based send_date
# -------------------------

dp = r.deceased_person
ydate = Hke::Heb.yahrzeit_date(
  dp.name,
  dp.hebrew_month_of_death,
  dp.hebrew_day_of_death
)

offsets = Array(resolved.how_many_days_before_yahrzeit_to_send_message).map(&:to_i).uniq.sort
offsets = [7] if offsets.empty?

candidates = offsets.map { |d| ydate - d.days }
expected = candidates.find { |d| d >= Date.today }

if expected.nil?
  next_y = ydate.next_year
  expected = offsets.map { |d| next_y - d.days }.find { |d| d >= Date.today }
end

assert("send_date uses preference offsets") do
  fm.send_date.to_date == expected
end

# -------------------------
# TEST 3 — delivery method from preferences
# -------------------------

pref_method = Array(resolved.delivery_priority).first&.to_s

assert("delivery_method from preferences") do
  pref_method.nil? || fm.delivery_method.to_s == pref_method
end

# -------------------------
# TEST 4 — approval gate blocks send
# -------------------------

fm.update!(approval_status: 0) # assume 0 = pending

before_sent = Hke::SentMessage.count

Hke::FutureMessageSendJob.perform_inline(fm.id, fm.community_id)

after_sent = Hke::SentMessage.count

assert("not approved message is not sent") do
  before_sent == after_sent && Hke::FutureMessage.exists?(fm.id)
end

# -------------------------
# TEST 5 — approved message sends + rolls
# -------------------------

fm.reload
fm.update!(approval_status: 1) # assume 1 = approved

before_future = r.future_messages.count
before_sent = Hke::SentMessage.count

Hke::FutureMessageSendJob.perform_inline(fm.id, fm.community_id)

after_sent = Hke::SentMessage.count
after_future = r.reload.future_messages.count

assert("approved message creates SentMessage") do
  after_sent == before_sent + 1
end

assert("rolling model recreates next FutureMessage") do
  after_future == 1
end

# -------------------------
# TEST 6 — token idempotency
# -------------------------

last_sent = Hke::SentMessage.last
token = last_sent.token

assert("SentMessage token unique") do
  Hke::SentMessage.where(token: token).count == 1
end
ActsAsTenant.current_tenant = nil
puts "\nTenant cleared"
puts "\n=== TEST RUN COMPLETE ===\n"
