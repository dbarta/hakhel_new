module Hke
  module ApplicationHelper

    def sort_link(column, label)
      current = params[:sort] == column
      direction = current && params[:direction] == "asc" ? "desc" : "asc"
      arrow = if current
        params[:direction] == "asc" ? "▲" : "▼"
      else
        ""
      end
      link_to "#{label} #{arrow}".html_safe, request.query_parameters.merge(sort: column, direction: direction)
    end

    def num_days_till_yahrzeit(deceased, reference_date = Time.zone.today)
      gregorian_yahrzeit_date = Hke.yahrzeit_date(
        deceased.name,
        deceased.hebrew_month_of_death,
        deceased.hebrew_day_of_death
      )
      [(gregorian_yahrzeit_date - reference_date).to_i, 0].max
    end

    def day_of_week_of_yahrzeit(deceased)
      hebrew_days = {
        0 => "ראשון",  # Sunday
        1 => "שני",    # Monday
        2 => "שלישי",  # Tuesday
        3 => "רביעי",  # Wednesday
        4 => "חמישי",  # Thursday
        5 => "שישי",   # Friday
        6 => "שבת"     # Saturday
      }
      gregorian_yahrzeit_date = Hke.yahrzeit_date(deceased.name, deceased.hebrew_month_of_death, deceased.hebrew_day_of_death)
      return hebrew_days[gregorian_yahrzeit_date.wday]
    end

    def hebrew_date_of_yahrzeit(deceased)
      "#{deceased.hebrew_day_of_death} #{deceased.hebrew_month_of_death}"
    end

    def num_of_years_gone(deceased)
      gregorian_yahrzeit_date = Hke.yahrzeit_date(deceased.name, deceased.hebrew_month_of_death, deceased.hebrew_day_of_death)
      years = gregorian_yahrzeit_date.year - deceased.date_of_death.year
      return years
    end

    def petirata(gender)
      gender == "male" ? "פטירתו" : "פטירתה"
    end

    def muzmenet(gender)
      gender == "male" ? "מוזמן" : "מוזמנת"
    end








    # selects records that match first_name or last_name to given key, returns array of ids.
    def select_by_name model, key
      sql_key = "%#{key}%"
      recs = model.select("id").where('first_name ILIKE ?', sql_key ).or(model.where('last_name ILIKE ?', sql_key ))
      recs_ids = recs.map{|x| x.id}
    end

    def sentence relation
      # "רבקה אפשטיין פטירה: י״ג תשרי תשס״ג 21.4.2008 איש קשר (בן): חנן אפשטיין (עוד 7 ימים)"
      d = relation.deceased_person
      deceased_name = d.name
      contact_name = relation.contact_person.name
      hebrew_date = "#{d.hebrew_year_of_death} #{d.hebrew_month_of_death} #{d.hebrew_day_of_death}"
      gregorian_date = d.date_of_death
      reltype = I18n.t(relation.relation_of_deceased_to_contact)
      num_days = 7
      "מר "+ deceased_name + ", תאריך פטירה " + hebrew_date + ", איש קשר: " +  contact_name  + "  (" + reltype + ") עוד " + num_days.to_s + " ימים"
    end

    def show_field_value(object, field)
      if object == nil
        display_value = t(field)
      elsif field.class != Hash
        display_value = object.send field
      else
        field_name = field[:field_name]
        action = field[:action]
        if action == :translate_to_hebrew
          raw_value = object.send field_name
          display_value = t('raw_value')
        else
          display_value = raw_value
        end
      end
    end


    def text_fld(form, name)
      content_tag(:div) do
        form.label(name, t(name.to_s), class: "text-xs") +
        form.text_field(name, class: "form-control text-xs")
      end
    end

    def text_fld_optional(form, name)
      content_tag(:div, "data-visibility-target": "hideable", hidden: true) do
        text_fld(form, name)
      end
    end

    # <i class="fa-solid fa-angle-up"></i>

    def toggle_visibility_button()
      def btn(hidden, icon)
        content_tag :div, "data-visibility-target": "hideable", hidden: hidden do
          content_tag :button, type: "button", "data-action":"click->visibility#toggleTargets" do
            content_tag "i", class: icon do
            end
          end
        end
      end
      btn(true, "fa-solid fa-angle-up") + btn(false, "fa-solid fa-angle-down")
    end


    def select_fld(form, name, options)
      content_tag(:div, class: "form-group") do
        form.label(name, t(name.to_s), class: "text-xs") +
        form.select(name,  options, {include_blank: true})
      end
    end

    def relations_select
      [ "father", "son", "grandfather", "grandson", "uncle",
        "mother", "daughter", "grandmother", "granddaughter",
        "aunt", "husband", "wife", "groom", "bride",
        "brother", "sister", "brother_in_law", "sister_in_law", "friend",
        "ex_wife", "ex_husband"].map{ |x| [I18n.t(x), x] }
    end

    def gender_select
      [ "male", "female" ].map{ |x| [I18n.t(x), x] }
      #[ [ "זכר" , "male" ],  [ "נקבה" , "female" ] ]
    end


    def hebrew_month_select
      ["תשרי","חשוון","כסלו","טבת","שבט","אדר","אדר א׳","אדר ב׳","ניסן","אייר","תמוז","אב","אלול","סיוון"]
    end

    def hebrew_day_select
      ["א׳","ב׳","ג׳","ד׳","ה׳","ו׳","ז׳","ח׳","ט׳","י׳","י״א","י״ב","י״ג","י״ד","ט״ו","ט״ז","י״ז","י״ח","י״ט","כ׳","כ״א","כ״ב","כ״ג","כ״ד","כ״ה","כ״ו","כ״ז","כ״ח","כ״ט","ל׳","ל״א"].map{|x| x.gsub("״",'"').gsub("׳","'")}
    end

    def generate_salutation gender
      gender == "male" ? "מר" : "גב׳"
    end

    def generate_alav_hashalom gender
      gender == "male" ? "עליו השלום" : "עליה השלום"
    end

    def generate_zal gender
      gender == "male" ? "זכרונו לברכה" : "זכרונה לברכה"
    end

    def conjugated_relationship deceased_gender, contact_gender, relationship_of_contact_to_deceased
      key = "d#{deceased_gender[0]}_c#{contact_gender[0]}"
      tr = {
        father: {dm_cm: "בנך", dm_cf: "בנך", df_cm: "בתך", df_cf: "בתך"},
        son: {dm_cm: "אביך", dm_cf: "אביך", df_cm: "אמך", df_cf: "אמך"},
        grandfather: {dm_cm: "נכדך", dm_cf: "נכדך", df_cm: "נכדתך", df_cf: "נכדתך"},
        grandson: {dm_cm: "סבך", dm_cf: "סבך", df_cm: "סבתך", df_cf: "סבתך"},
        uncle: {dm_cm: "אחיינך", dm_cf: "אחיינך", df_cm: "אחייניתך", df_cf: "אחייניתך"},
        mother: {dm_cm: "בנך", dm_cf: "בנך", df_cm: "בתך", df_cf: "בתך"},
        daughter: {dm_cm: "אביך", dm_cf: "אביך", df_cm: "אמך", df_cf: "אמך"},
        grandmother: {dm_cm:  "נכדך", dm_cf: "נכדך", df_cm: "נכדתך", df_cf: "נכדתך"},
        granddaughter: {dm_cm: "סבך", dm_cf: "סבך", df_cm: "סבתך", df_cf: "סבתך"},
        aunt: {dm_cm: "אחיינך", dm_cf: "אחיינך", df_cm: "אחייניתך", df_cf: "אחייניתך"},
        husband: {dm_cm: "בעלך", dm_cf: "בעלך", df_cm: "אשתך", df_cf: "אשתך"},
        wife: {dm_cm: "בעלך", dm_cf: "בעלך", df_cm: "אשתך", df_cf: "אשתך"},
        groom:{dm_cm:"חתנך", dm_cf: "חתנך", df_cm: "כלתך", df_cf: "כלתך"},
        bride: {dm_cm: "חתנך", dm_cf: "", df_cm: "", df_cf: ""},
        brother: {dm_cm: "אחיך", dm_cf: "אחיך", df_cm: "אחותך", df_cf: "אחותך"},
        sister: {dm_cm: "אחיך", dm_cf: "אחיך", df_cm: "אחותך", df_cf: "אחותך"},
        brother_in_law: {dm_cm: "גיסך", dm_cf: "גיסך", df_cm: "גיסתך", df_cf: "גיסתך"},
        sister_in_law: {dm_cm: "גיסך", dm_cf: "גיסך", df_cm: "גיסתך", df_cf: "גיסתך"},
        friend: {dm_cm: "חברך", dm_cf: "חברך", df_cm: "חברתך", df_cf: "חברתך"},
        ex_wife:  {dm_cm: "בעלך לשעבר", dm_cf: "בעלך לשעבר", df_cm: "אשתך לשעבר", df_cf: "אשתך לשעבר"},
        ex_husband: {dm_cm: "בעלך לשעבר", dm_cf: "בעלך לשעבר", df_cm: "אשתך לשעבר", df_cf: "אשתך לשעבר"},
      }
      puts "@@@@@  relationship_of_contact_to_deceased.to_sym: #{relationship_of_contact_to_deceased.to_sym}"
      puts "@@@@@  key.to_sym: #{key.to_sym}"
      tr[relationship_of_contact_to_deceased.to_sym][key.to_sym]
    end

    def test_tr r
      conjugated_relationship r.deceased_person.gender, r.contact_person.gender, r.relation_of_deceased_to_contact
    end

    def generate_welcome gender
      gender == "male" ? "ברוך הבא" : "ברוכה הבאה"
    end
  end
end