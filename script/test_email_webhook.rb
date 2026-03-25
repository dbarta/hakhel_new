# Test SendGrid end-to-end: send → webhook → delivery_status in UI
#
# Usage:
#   bin/rails runner script/test_email_webhook.rb          # 1 message
#   bin/rails runner script/test_email_webhook.rb 3        # 3 messages
#
# What it does:
#   1. Picks N approved FutureMessages
#   2. Creates a DUPLICATE of each (original is untouched)
#   3. Runs FutureMessageSendJob inline on the duplicate
#   4. The job sends the email and creates a SentMessage with sendgrid_message_id,
#      then deletes the duplicate FutureMessage
#   5. Any duplicate not consumed by the job is cleaned up at the end
#
# Test messages are identifiable in the UI by email: david+sgtest@hakhel.net

TEST_EMAIL = "david@odeca.net"
count = (ARGV.first || 1).to_i

candidates = Hke::FutureMessage
  .approved_messages
  .where.not(community_id: nil)
  .limit(count)
  .to_a

if candidates.empty?
  puts "No approved FutureMessages found."
  exit 1
end

puts "Creating #{candidates.size} test duplicate(s) and running jobs...\n"

duplicate_ids = []

candidates.each do |original|
  community = Hke::Community.find(original.community_id)

  ActsAsTenant.with_tenant(community) do
    dup = Hke::FutureMessage.new(
      messageable: original.messageable,
      message_type: original.message_type,
      community_id: original.community_id,
      send_date: Date.today,
      delivery_method: :email,
      email: TEST_EMAIL,
      phone: nil,
      approval_status: :approved
    )

    unless dup.save
      puts "  Could not create duplicate for FutureMessage ##{original.id}: #{dup.errors.full_messages.join(", ")}"
      next
    end

    duplicate_ids << dup.id
    puts "  Duplicate ##{dup.id} created from original ##{original.id}"

    before_count = Hke::SentMessage.count

    begin
      Hke::FutureMessageSendJob.new.perform(dup.id, community.id)
    rescue => e
      puts "  ERROR running job for duplicate ##{dup.id}: #{e.class}: #{e.message}"
      next
    end

    if Hke::SentMessage.count > before_count
      sent = Hke::SentMessage.where(community_id: community.id).order(:created_at).last
      puts "  SentMessage ##{sent.id} created"
      puts "    sendgrid_message_id: #{sent.sendgrid_message_id.presence || "(missing — email may not have sent)"}"
      puts "    delivery_status:     #{sent.delivery_status.presence || "(pending — waiting for webhook)"}"
      duplicate_ids.delete(dup.id)  # job already deleted it
    elsif !Hke::FutureMessage.exists?(dup.id)
      puts "  Duplicate ##{dup.id} deleted but no SentMessage created — check logs"
      duplicate_ids.delete(dup.id)
    else
      puts "  Job re-enqueued duplicate ##{dup.id} (outside send window — run after 9 AM Israel time)"
    end
  end
end

# Clean up any duplicates the job didn't consume
if duplicate_ids.any?
  puts "\nCleaning up #{duplicate_ids.size} unconsumed duplicate(s): #{duplicate_ids.join(", ")}"
  Hke::FutureMessage.where(id: duplicate_ids).delete_all
end

puts "\nDone."
puts "View results in the UI under הודעות → הודעות שנשלחו — look for email: #{TEST_EMAIL}"
puts "Delivery status will update to 'delivered' once the SendGrid webhook fires (usually within seconds)."
