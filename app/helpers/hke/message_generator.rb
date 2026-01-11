module Hke::MessageGenerator
  extend ActiveSupport::Concern
  include Hke::ApplicationHelper

  def generate_msg_data(relation, reference_date:)
    return {} unless relation

    c = relation.contact_person
    d = relation.deceased_person

    {
      c_name: c.name,
      c_first_name: c.first_name,
      c_last_name: c.last_name,
      c_salutation: generate_salutation(c.gender),
      welcome: generate_welcome(c.gender),
      muzmenet: muzmenet(c.gender),
      d_name: d.name,
      d_first_name: d.first_name,
      d_last_name: d.last_name,
      d_salutation: generate_salutation(d.gender),
      alav: generate_alav_hashalom(d.gender),
      relation: conjugated_relationship(d.gender, c.gender, relation.relation_of_deceased_to_contact),
      num_days_till: num_days_till_yahrzeit(d, reference_date),
      day_of_week: day_of_week_of_yahrzeit(d),
      heb_month_and_day: hebrew_date_of_yahrzeit(d),
      yahrzeit_years: num_of_years_gone(d),
      petirata: petirata(d.gender)

    }
  end

  def generate_hebrew_snippets(relation, modalities = [:web, :sms], reference_date:)

    return {} unless relation

    msg_data = generate_msg_data(relation, reference_date: reference_date)
    context = msg_data.transform_keys(&:to_s)

    snippets = {}
    snippets[:web] = Hke::LiquidRenderer.render("reminder.html", context, category: "web") if modalities.include?(:web)
    snippets[:sms] = Hke::LiquidRenderer.render("reminder.txt", context, category: "sms") if modalities.include?(:sms)
    snippets[:email] = Hke::LiquidRenderer.render("reminder.email", context, category: "email") if modalities.include?(:email)
    snippets[:whatsapp] = Hke::LiquidRenderer.render("reminder.whatsapp", context, category: "whatsapp") if modalities.include?(:whatsapp)

    snippets
  end
end
