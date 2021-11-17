module Spree
  module Webhooks
    class Subscriber < Spree::Webhooks::Base
      SUPPORTED_CUSTOM_EVENTS = {
        order: %w[order.canceled order.paid order.placed order.resumed order.shipped],
        payment: %w[payment.paid payment.voided],
        product: %w[product.back_in_stock product.backorderable product.discontinued product.out_of_stock],
        variant: %w[variant.back_in_stock variant.backorderable variant.discontinued variant.out_of_stock],
        shipment: %w[shipment.shipped],
      }

      has_many :events, inverse_of: :subscriber

      validates :url, 'spree/url': true, presence: true

      validate :check_uri_path

      self.whitelisted_ransackable_attributes = %w[active subscriptions url]
      self.whitelisted_ransackable_associations = %w[event]

      scope :active, -> { where(active: true) }
      scope :inactive, -> { where(active: false) }

      before_save :parse_subscriptions

      def self.with_urls_for(event)
        where(
          case ActiveRecord::Base.connection.adapter_name
          when 'Mysql2'
            ["('*' MEMBER OF(subscriptions) OR ? MEMBER OF(subscriptions))", event]
          when 'PostgreSQL'
            ["subscriptions @> '[\"*\"]' OR subscriptions @> ?", [event].to_json]
          end
        )
      end

      class << self
        def supported_events
          Spree::Base.descendants.
            select { |model| model.included_modules.include? Spree::Webhooks::HasWebhooks }.
            to_h do |model|
            model_name = model.name.demodulize.underscore.to_sym
            [model_name, events_list_for(model_name)]
          end
        end

        def events_list_for(model)
          result = default_events(model)
          result += SUPPORTED_CUSTOM_EVENTS[model] if SUPPORTED_CUSTOM_EVENTS.include?(model)
          result
        end

        def default_events(model)
          %W[#{model}.create #{model}.update #{model}.delete]
        end
      end

      private

      def check_uri_path
        uri = begin
          URI.parse(url)
        rescue URI::InvalidURIError
          return false
        end

        errors.add(:url, 'the URL must have a path') if uri.blank? || uri.path.blank?
      end

      def parse_subscriptions
        return if subscriptions.blank? || subscriptions.is_a?(Array)

        self.subscriptions = JSON.parse(subscriptions)
      end
    end
  end
end
