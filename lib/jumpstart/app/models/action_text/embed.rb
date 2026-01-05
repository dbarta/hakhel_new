require "net/http"

class ActionText::Embed < ApplicationRecord
  include ActionText::Attachable

  # Implements a matching PermitScrubber to Rails that allows scripts from trusted sources
  # https://github.com/rails/rails-html-sanitizer/blob/main/lib/rails/html/sanitizer.rb#L156-L167
  class Scrubber < Rails::HTML::PermitScrubber
    def initialize(...)
      super
      self.tags = ActionText::ContentHelper.allowed_tags || (ActionText::ContentHelper.sanitizer.class.allowed_tags + [ ActionText::Attachment.tag_name, "figure", "figcaption", "iframe", "blockquote", "time" ])
      self.attributes = ActionText::ContentHelper.allowed_attributes || (ActionText::ContentHelper.sanitizer.class.allowed_attributes + ActionText::Attachment::ATTRIBUTES + [ "data-id", "data-flickr-embed", "target", "allow", "frameborder", "referrerpolicy", "allowfullscreen", "loading" ])
    end

    def scrub(node)
      if node.name == "script" && ActionText::Embed.allowed_script?(node)
        STOP
      else
        super
      end
    end
  end

  # Allowed script src URLs for OEmbeds
  ALLOWED_SCRIPTS = [
    /^\/\/s.imgur.com/,
    /^https:\/\/platform.twitter.com/
  ]

  # Any providers that don't support discovery can be added here
  PROVIDERS = {
    x: {
      endpoint: "https://publish.twitter.com/oembed",
      urls: [
        Regexp.new("^https:\\/\\/([^\\.]+\\.)?twitter\\.com\\/(.*?)\\/status\\/(.*?)"),
        Regexp.new("^https:\\/\\/([^\\.]+\\.)?x\\.com\\/(.*?)\\/status\\/(.*?)")
      ]
    }
  }.freeze

  # Returns an ActionText::Embed for a given URL
  def self.from_url(url) = find_by(url: url) || from_oembed(url)

  # Creates an ActionText::Embed from a URL
  def self.from_oembed(url)
    return unless allowed?(url)

    if (endpoint = endpoint_for(url))
      uri = URI.parse(endpoint).tap { it.query = {url: url}.to_query }
      response = JSON.parse Net::HTTP.get(uri)
      create(url: url, fields: response)
    end
  end

  # Returns OEmbed endpoint for URL
  def self.endpoint_for(url)
    provider_for(url)&.dig(:endpoint) || discover_endpoint_for(url)
  end

  def self.provider_for(url)
    PROVIDERS.values.find do |conf|
      conf.dig(:urls).any? { it.match?(url) }
    end
  end

  # Retrieves OEmbed URL from HTML page
  def self.discover_endpoint_for(url)
    doc = Nokogiri::HTML(Net::HTTP.get(URI(url)))
    if (link = doc.xpath("//link[contains(@type, 'json+oembed')]/@href").first)
      URI.parse(link).tap { it.query = nil }.to_s
    end
  rescue URI::Error
  end

  # Checks if URL is allowed for embedding
  def self.allowed?(url) = endpoint_for(url)

  # Returns boolean if embed's script tags are allowed
  def self.allowed_script?(node)
    (src = node.attr("src")) && ALLOWED_SCRIPTS.any? { |pattern| pattern.match?(src) }
  end

  def self.delegate_fields(*keys)
    keys.each do |key|
      define_method(key) { fields[key.to_s] }
    end
  end

  delegate_fields :type, :version, :title, :author_name, :author_url, :provider_name, :provider_url, :thumbnail_url, :thumbnail_width, :thumbnail_height, :height, :width, :html

  %w[link photo rich video].each do |embed_type|
    define_method :"#{embed_type}?" do
      type == embed_type
    end
  end

  def attachable_plain_text_representation(caption = nil) = "[#{caption || url}]"

  def content_type = "application/vnd.actiontext.embed"
end
