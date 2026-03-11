module Hke
  module Portal
    class DashboardController < BaseController
      def show
        @relations = @contact.relations.includes(:deceased_person, :future_messages)
      end
    end
  end
end
