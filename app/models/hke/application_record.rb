module Hke
  class ApplicationRecord < ::ApplicationRecord #ActiveRecord::Base
    self.abstract_class = true
  end
end
