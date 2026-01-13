require "liquid"

module Hke
  class LiquidRenderer
    def self.render(template_name, data, category: "web")
      # Load the template from the app (engine inlined into app/)
      template_path = Rails.root.join("app/views/hke/liquid_templates/#{category}/#{template_name}.liquid")

      # Read and parse the template
      template_content = File.read(template_path)
      template = Liquid::Template.parse(template_content)

      # Render with provided data
      template.render(data)
    end
  end
end
