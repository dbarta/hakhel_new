module Hke
  module HebrewSelects
    extend ActiveSupport::Concern

    def gender_select
      [ "male", "female" ].map { |x| [I18n.t(x), x] }
    end

    def hebrew_month_select
      ["תשרי","חשוון","כסלו","טבת","שבט","אדר","אדר א׳","אדר ב׳","ניסן","אייר","תמוז","אב","אלול","סיוון"]
    end

    def hebrew_day_select
      ["א׳","ב׳","ג׳","ד׳","ה׳","ו׳","ז׳","ח׳","ט׳","י׳","י״א","י״ב","י״ג","י״ד","ט״ו","ט״ז","י״ז","י״ח","י״ט","כ׳","כ״א","כ״ב","כ״ג","כ״ד","כ״ה","כ״ו","כ״ז","כ״ח","כ״ט","ל׳","ל״א"].map { |x| x.gsub("״",'"').gsub("׳","'") }
    end
  end
end
