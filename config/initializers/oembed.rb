# Allow injecting OEmbed HTML into ActionText, but only allow script tags from trusted sources
# Soundcloud, Spotify, Vimeo, and YouTube use iframe embeds instead of script tags
Rails.application.config.to_prepare do
  ActionText::ContentHelper.scrubber = ActionText::Embed::Scrubber.new
end
