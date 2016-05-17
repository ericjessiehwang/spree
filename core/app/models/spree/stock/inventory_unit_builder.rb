module Spree
  module Stock
    class InventoryUnitBuilder
      def initialize(order)
        @order = order
      end

      def units
        @order.line_items.flat_map do |line_item|
          Array.new(line_item.quantity) do |_i|
            @order.inventory_units.build(
              pending: true,
              variant_id: line_item.variant_id,
              line_item: line_item,
              order: @order
            )
          end
        end
      end
    end
  end
end
