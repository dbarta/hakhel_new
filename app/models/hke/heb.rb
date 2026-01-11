require "httparty"
require "json"

module Hke
  module Heb
    # Simple caches/flags
    @heb_debug = false
    @h2g_cache = {}
    @g2h_cache = {}

    # Control debug output
    def heb_debug=(value)
      @heb_debug = value
    end

    def debug_puts(message)
      puts message if @heb_debug
    end

    # Returns the hebrew letter number, or zero if not a hebrew letter
    def hebrew_letter_to_number(aleph)
      debug_puts "@@@ in hebrew_letter_to_number, aleph: #{aleph}"
      i = "אבגדהוזחטיכלמנסעפצקרשת".index(aleph)
      if i.nil?
        # Maybe ot sofit
        i = "אבגדהוזחטיךלםןסעףץקרשת".index(aleph)
      end
      result = i.nil? ? 0 : [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 200, 300, 400][i]
      debug_puts "@@@ Out of hebrew_letter_to_number, return: #{result}"
      result
    end

    def clean_name(text)
      debug_puts "@@@ in clean_name, text: #{text}"
      letters = "ךלםןסעףץאבגדהוזחטיכלמנסעפצקרשת "
      text.chars.filter { |a| letters.include?(a) }.join.tap do |text1|
        debug_puts "@@@ Out of clean_name, return: #{text1}"
      end
    end

    def hebrew_month_to_english(hebrew_month)
      debug_puts "@@@ in hebrew_month_to_english, hebrew_month: #{hebrew_month}"
      h = clean_name(hebrew_month)
      mt = {"ניסן" => :Nisan, "אייר" => :Iyyar, "סיון" => :Sivan, "סיוון" => :Sivan, "תמוז" => :Tamuz,
            "אב" => :Av, "אלול" => :Elul, "תשרי" => :Tishrei, "חשון" => :Cheshvan,
            "חשוון" => :Cheshvan,
            "כסלו" => :Kislev, "כסליו" => :Kislev, "טבת" => :Tevet, "שבט" => :Shvat, "אדר" => :Adar,
            "אדר א" => :Adar1,
            "אדר ב" => :Adar2}
      result = mt[h]
      debug_puts "@@@ Out of hebrew_month_to_english, return: #{result}"
      result
    end

    def english_month_to_hebrew(english_month)
      debug_puts "@@@ in english_month_to_hebrew, english_month: #{english_month}"
      mt = {
        Tishrei: "תשרי",
        Cheshvan: "חשוון",
        Kislev: "כסלו",
        Tevet: "טבת",
        Shvat: "שבט",
        Adar: "אדר",
        Adar1: "אדר א׳",
        Adar2: "אדר ב׳",
        Nisan: "ניסן",
        Iyyar: "אייר",
        Sivan: "סיוון",
        Tamuz: "תמוז",
        Av: "אב",
        Elul: "אלול"
      }
      result = mt[english_month]
      debug_puts "@@@ Out of english_month_to_hebrew, return: #{result}"
      result
    end

    def hebrew_date_numeric_value(day)
      debug_puts "@@@ in hebrew_date_numeric_value, day: #{day}"
      result = clean_name(day).chars.map { |a| hebrew_letter_to_number(a) }.sum
      debug_puts "@@@ Out of hebrew_date_numeric_value, return: #{result}"
      result
    end

    def prepare_hebrew_date_for_hebcal(year, month, day)
      debug_puts "@@@ in prepare_hebrew_date_for_hebcal, year: #{year}, month: #{month}, day: #{day}"
      m = hebrew_month_to_english(month)
      d = hebrew_date_numeric_value(day)
      y = if year.is_a?(String)
        year.chars.map { |a| hebrew_letter_to_number(a) }.sum.then { |val| val + 5000 - ((year[0] == "ה") ? 5 : 0) }
      else
        year
      end
      result = [y, m, d]
      debug_puts "@@@ Out of prepare_hebrew_date_for_hebcal, return: #{result}"
      result
    end

    def h2g(name, y, m, d)
      debug_puts "@@@ in h2g, name: #{name}, year: #{y}, month: #{m}, day: #{d}"
      key = "#{y}-#{m}-#{d}"
      @h2g_cache ||= {}
      return @h2g_cache[key] if @h2g_cache[key]
      return nil unless y && m && d

      v = prepare_hebrew_date_for_hebcal(y, m, d)
      uri = "https://www.hebcal.com/converter?cfg=json&hy=#{v[0]}&hm=#{v[1]}&hd=#{v[2]}&h2g=1"
      response = HTTParty.get(uri)
      result = nil
      begin
        payload = JSON.parse(response.body)
        result = Date.new(payload["gy"], payload["gm"], payload["gd"])
      rescue => e
        puts "Error in Date for #{response.body}: #{e.message}"
      end
      debug_puts "@@@ Out of h2g, return: #{result}"
      @h2g_cache[key] = result
      result
    end

    def g2h(name, date)
      debug_puts "@@@ in g2h, name: #{name}, date: #{date}"
      @g2h_cache ||= {}
      return @g2h_cache[date] if @g2h_cache[date]
      return nil unless date.is_a?(Date)

      date_str = date.strftime("%Y-%m-%d")
      debug_puts "@@@ In g2h, date: #{date}, date_str: #{date_str}"
      uri = "https://www.hebcal.com/converter?cfg=json&date=#{date_str}&g2h=1&strict=1"
      response = HTTParty.get(uri)
      result = (response.code == 200) ? JSON.parse(response.body) : nil
      debug_puts "@@@ Out of g2h, return: #{result}"
      @g2h_cache[date] = result
      result
    end

    def current_hebrew_year
      debug_puts "@@@ in current_hebrew_year"
      result = g2h("No One", Date.current)["hy"]
      debug_puts "@@@ Out of current_hebrew_year, return: #{result}"
      result
    end

    def next_hebrew_date(name, hebrew_month, hebrew_day)
      debug_puts "@@@ in next_hebrew_date, name: #{name}, hebrew_month: #{hebrew_month}, hebrew_day: #{hebrew_day}"
      hy = current_hebrew_year
      gdate = h2g(name, hy, hebrew_month, hebrew_day)
      hy = (gdate < Date.today) ? hy + 1 : hy
      result = {hy: hy, hm: hebrew_month, hd: hebrew_day}
      debug_puts "@@@ Out of next_hebrew_date, return: #{result}"
      result
    end

    # Returns the nearest future gregorian yahrzeit date
    def yahrzeit_date(name, hebrew_month, hebrew_day)
      debug_puts "@@@ in yahrzeit_date, name: #{name}, hebrew_month: #{hebrew_month}, hebrew_day: #{hebrew_day}"
      hyd = next_hebrew_date(name, hebrew_month, hebrew_day)
      result = h2g(name, hyd[:hy], hyd[:hm], hyd[:hd])
      debug_puts "@@@ Out of yahrzeit_date, return: #{result}"
      result
    end
  end

  extend Heb
  @heb_debug = false
  @h2g_cache = {}
  @g2h_cache = {}
end
