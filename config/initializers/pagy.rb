require "pagy"

# Fallback stub if Pagy::Backend is not autoloaded by default
class Pagy
  module Backend; end unless const_defined?(:Backend)
end
