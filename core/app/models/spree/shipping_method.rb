module Spree
  class ShippingMethod < Spree::Base
    acts_as_paranoid
    include Spree::Core::CalculatedAdjustments
    DISPLAY = [:both, :front_end, :back_end]

    # Used for #refresh_rates
    DISPLAY_ON_FRONT_AND_BACK_END = 0
    DISPLAY_ON_FRONT_END = 1
    DISPLAY_ON_BACK_END = 2

    default_scope -> { where(deleted_at: nil) }

    has_many :shipping_method_categories, :dependent => :destroy
    has_many :shipping_categories, through: :shipping_method_categories
    has_many :shipping_rates, inverse_of: :shipping_method
    has_many :shipments, :through => :shipping_rates

    has_and_belongs_to_many :zones, :join_table => 'spree_shipping_methods_zones',
                                    :class_name => 'Spree::Zone',
                                    :foreign_key => 'shipping_method_id'

    belongs_to :tax_category, :class_name => 'Spree::TaxCategory'

    validates :name, presence: true

    validate :at_least_one_shipping_category

    def include?(address)
      return false unless address
      zones.any? do |zone|
        zone.include?(address)
      end
    end

    def build_tracking_url(tracking)
      return if tracking.blank? || tracking_url.blank?
      tracking_url.gsub(/:tracking/, ERB::Util.url_encode(tracking)) # :url_encode exists in 1.8.7 through 2.1.0
    end

    def self.calculators
      spree_calculators.send(model_name_without_spree_namespace).select{ |c| c < Spree::ShippingCalculator }
    end

    # Some shipping methods are only meant to be set via backend
    def frontend?
      self.display_on != "back_end"
    end

    def tax_category
      Spree::TaxCategory.unscoped { super }
    end

    def available_to_ui(ui_filter)
      ui_filter == DISPLAY_ON_FRONT_AND_BACK_END ||
      (method.frontend? && ui_filter == DISPLAY_ON_FRONT_END) ||
      (!method.frontend? && ui_filter == DISPLAY_ON_BACK_END)
    end

    private
      def compute_amount(calculable)
        self.calculator.compute(calculable)
      end

      def at_least_one_shipping_category
        if self.shipping_categories.empty?
          self.errors[:base] << "You need to select at least one shipping category"
        end
      end

      def self.on_backend_query
        "#{table_name}.display_on != 'front_end' OR #{table_name}.display_on IS NULL"
      end

      def self.on_frontend_query
        "#{table_name}.display_on != 'back_end' OR #{table_name}.display_on IS NULL"
      end
  end
end
