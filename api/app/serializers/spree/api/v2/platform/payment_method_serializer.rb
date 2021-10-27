module Spree
  module Api
    module V2
      module Platform
        class PaymentMethodSerializer < BaseSerializer
          attributes :name, :type, :description, :active, :display_on, :auto_capture, :position

          attribute :preferences do |payment_method|
            payment_method.preferences
          end

          has_many :stores
        end
      end
    end
  end
end
