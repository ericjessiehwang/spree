module Spree
  class LineItem < Spree::Base
    before_validation :adjust_quantity
    belongs_to :order, class_name: "Spree::Order", inverse_of: :line_items, touch: true
    belongs_to :variant, class_name: "Spree::Variant", inverse_of: :line_items
    belongs_to :tax_category, class_name: "Spree::TaxCategory"

    has_one :product, through: :variant

    has_many :adjustments, as: :adjustable, dependent: :destroy, class_name: "Spree::Adjustment"
    has_many :inventory_units, inverse_of: :line_item

    before_validation :copy_price

    validates :variant, presence: true
    validates :quantity, numericality: {
      only_integer: true,
      greater_than: -1,
      message: Spree.t('validation.must_be_int')
    }
    validates :price, numericality: true
    validates_with Stock::AvailabilityValidator

    validate :ensure_proper_currency
    before_destroy :update_inventory

    after_save :update_inventory
    after_save :update_adjustments

    delegate :name, :description, :sku, :should_track_inventory?, to: :variant

    attr_accessor :target_shipment

    def copy_price
      if variant
        self.price = variant.price if price.nil?
        self.cost_price = variant.cost_price if cost_price.nil?
        self.currency = variant.currency if currency.nil?
      end
    end

    def amount
      price * quantity
    end
    alias subtotal amount

    def discounted_amount
      amount + promo_total
    end

    def final_amount
      amount + adjustment_total
    end
    alias total final_amount

    def single_money
      Spree::Money.new(price, { currency: currency })
    end
    alias single_display_amount single_money

    def money
      Spree::Money.new(amount, { currency: currency })
    end
    alias display_total money
    alias display_amount money

    def adjust_quantity
      self.quantity = 0 if quantity.nil? || quantity < 0
    end

    def sufficient_stock?
      Stock::Quantifier.new(variant).can_supply? quantity
    end

    def insufficient_stock?
      !sufficient_stock?
    end

    # Remove product default_scope `deleted_at: nil`
    def product
      variant.product
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    # Rounding down so that:
    #   total_per_item * quantity <= total
    def rounded_total_per_item
      (total / quantity).round(2, :down)
    end

    def display_rounded_total_per_item
      Spree::Money.new(rounded_total_per_item, { currency: currency })
    end

    private
      def update_inventory
        if changed? || target_shipment.present?
          Spree::OrderInventory.new(self.order, self).verify(target_shipment)
        end
      end

      def update_adjustments
        if quantity_changed?
          recalculate_adjustments
        end
      end

      def recalculate_adjustments
        Spree::ItemAdjustments.new(self).update
      end

      def ensure_proper_currency
        unless currency == order.currency
          errors.add(:currency, I18n.t(:must_match_order_currency))
        end
      end
  end
end
