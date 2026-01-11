module Hke
  class CommunityRecord < ApplicationRecord
    self.abstract_class = true
    acts_as_tenant :community, class_name: 'Hke::Community' if defined? ActsAsTenant
  end
end
