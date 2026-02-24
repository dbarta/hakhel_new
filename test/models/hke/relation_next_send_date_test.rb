require "test_helper"

class Hke::RelationNextSendDateTest < ActiveSupport::TestCase
  setup do
    # Create test data from scratch, suppressing callbacks that need
    # external services (Sidekiq::Cron, HebCal API).

    account = Account.create!(name: "Test Account", personal: false, owner: users(:one))

    # Suppress Community after_create callbacks (schedule_daily_job uses Sidekiq::Cron)
    begin
      Hke::Community.skip_callback(:create, :after, :schedule_daily_job)
    rescue
      nil
    end
    @community = Hke::Community.create!(
      name: "Test Community",
      community_type: :synagogue,
      account: account
    )

    ActsAsTenant.current_tenant = @community

    @dp = Hke::DeceasedPerson.new(
      first_name: "אברהם",
      last_name: "כהן",
      gender: "male",
      hebrew_year_of_death: "התשפ\"ג",
      hebrew_month_of_death: "תשרי",
      hebrew_day_of_death: "י'",
      community: @community
    )
    @dp.save!(validate: false)

    @cp = Hke::ContactPerson.new(
      first_name: "רונן",
      last_name: "כהן",
      gender: "male",
      phone: "050-1234567",
      community: @community
    )
    @cp.save!(validate: false)

    # Suppress Relation after_commit (process_future_messages calls HebCal API)
    Hke::Relation.skip_callback(:commit, :after, :process_future_messages)
    @relation = Hke::Relation.create!(
      deceased_person: @dp,
      contact_person: @cp,
      relation_of_deceased_to_contact: "son",
      community: @community
    )

    # A fixed yahrzeit date 10 days from today — gives room for offset testing
    @fake_yahrzeit = Time.zone.today + 10.days
  end

  teardown do
    ActsAsTenant.current_tenant = nil
    # Restore callbacks
    begin
      Hke::Relation.set_callback(:commit, :after, :process_future_messages)
    rescue
      nil
    end
    begin
      Hke::Community.set_callback(:create, :after, :schedule_daily_job)
    rescue
      nil
    end
  end

  # ----------------------------------------------------------------
  # Helper: call the private method directly
  # ----------------------------------------------------------------
  def call_next_send_date(relation, yahrzeit_date, offsets)
    relation.send(
      :next_send_date_from_offsets,
      @dp.name,
      @dp.hebrew_month_of_death,
      @dp.hebrew_day_of_death,
      yahrzeit_date,
      offsets
    )
  end

  # ----------------------------------------------------------------
  # Test 1: No sent message today → today is a valid candidate
  # ----------------------------------------------------------------
  test "returns today when offset matches today and no sent message exists" do
    offsets = [10]

    Hke::Heb.stub :yahrzeit_date, @fake_yahrzeit do
      result = call_next_send_date(@relation, @fake_yahrzeit, offsets)
      assert_equal Time.zone.today, result,
        "Should return today when no sent message exists for today"
    end
  end

  # ----------------------------------------------------------------
  # Test 2: Sent message exists today → skip today, pick next date
  # ----------------------------------------------------------------
  test "skips today when a sent message already exists for today" do
    offsets = [10, 3]  # 10 days before = today, 3 days before = yahrzeit - 3

    Hke::SentMessage.create!(
      messageable: @relation,
      community: @community,
      send_date: Time.zone.now,
      delivery_method: :sms,
      full_message: "test message",
      phone: "050-1234567"
    )

    Hke::Heb.stub :yahrzeit_date, @fake_yahrzeit do
      result = call_next_send_date(@relation, @fake_yahrzeit, offsets)

      expected = @fake_yahrzeit - 3.days
      assert_equal expected, result,
        "Should skip today and return the next offset date (yahrzeit - 3)"
    end
  end

  # ----------------------------------------------------------------
  # Test 3: All offsets in the past → falls through to next year
  # ----------------------------------------------------------------
  test "falls through to next year yahrzeit when all offsets are past" do
    past_yahrzeit = Time.zone.today - 5.days
    offsets = [10, 7]

    # Stub returns the current (past) yahrzeit; the code calls .next_year on it
    Hke::Heb.stub :yahrzeit_date, past_yahrzeit do
      result = call_next_send_date(@relation, past_yahrzeit, offsets)

      next_year_yahrzeit = past_yahrzeit.next_year
      expected_candidates = offsets.sort.map { |d| next_year_yahrzeit - d.days }
      expected = expected_candidates.find { |dt| dt >= Time.zone.today }

      assert_equal expected, result,
        "Should fall through to next year's yahrzeit offsets"
    end
  end

  # ----------------------------------------------------------------
  # Test 4: Sent message today + all remaining offsets past → next year
  # ----------------------------------------------------------------
  test "returns next year date when sent today and all offsets exhausted" do
    yahrzeit_today = Time.zone.today
    offsets = [0]

    Hke::SentMessage.create!(
      messageable: @relation,
      community: @community,
      send_date: Time.zone.now,
      delivery_method: :sms,
      full_message: "test message",
      phone: "050-1234567"
    )

    # Stub returns today's yahrzeit; the code calls .next_year on it
    Hke::Heb.stub :yahrzeit_date, yahrzeit_today do
      result = call_next_send_date(@relation, yahrzeit_today, offsets)

      assert_equal yahrzeit_today.next_year, result,
        "Should return next year's yahrzeit date when today is skipped"
    end
  end
end
