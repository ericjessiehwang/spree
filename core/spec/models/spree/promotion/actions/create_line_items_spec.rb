require 'spec_helper'

describe Spree::Promotion::Actions::CreateLineItems, :type => :model do
  let(:order) { create(:order) }
  let(:action) { Spree::Promotion::Actions::CreateLineItems.create }
  let(:promotion) { stub_model(Spree::Promotion) }
  let(:shirt) { create(:variant) }
  let(:mug) { create(:variant) }

  def empty_stock(variant)
    variant.stock_items.update_all(backorderable: false)
    variant.stock_items.each { |i| i.reduce_count_on_hand_to_zero }
  end

  context "#perform" do
    before do
      allow(action).to receive_messages :promotion => promotion
      action.promotion_action_line_items.create!(
        :variant => mug,
        :quantity => 1
      )
      action.promotion_action_line_items.create!(
        :variant => shirt,
        :quantity => 2
      )
    end

    context "order is eligible" do
      before do
        allow(promotion).to receive_messages :eligible => true
      end

      it "adds line items to order with correct variant and quantity" do
        action.perform(:order => order)
        expect(order.line_items.count).to eq(2)
        line_item = order.line_items.find_by_variant_id(mug.id)
        expect(line_item).not_to be_nil
        expect(line_item.quantity).to eq(1)
      end

      it "only adds the delta of quantity to an order" do
        order.contents.add(shirt, 1)
        action.perform(:order => order)
        line_item = order.line_items.find_by_variant_id(shirt.id)
        expect(line_item).not_to be_nil
        expect(line_item.quantity).to eq(2)
      end

      it "doesn't add if the quantity is greater" do
        order.contents.add(shirt, 3)
        action.perform(:order => order)
        line_item = order.line_items.find_by_variant_id(shirt.id)
        expect(line_item).not_to be_nil
        expect(line_item.quantity).to eq(3)
      end

      it "doesn't try to add an item if it's out of stock" do
        empty_stock(mug)
        empty_stock(shirt)

        expect(order.contents).to_not receive(:add)
        action.perform(:order => order)
      end
    end
  end

  describe '#item_available?' do
    let(:item_out_of_stock) { action.promotion_action_line_items.create!(:variant => mug, :quantity => 1) }
    let(:item_in_stock) { action.promotion_action_line_items.create!(:variant => shirt, :quantity => 1) }

    it "returns false if the item is out of stock" do 
      empty_stock(mug)
      expect(action.item_available? item_out_of_stock).to be false
    end

    it "returns true if the item is in stock" do 
      expect(action.item_available? item_in_stock).to be true
    end
  end
end
