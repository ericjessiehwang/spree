require 'spec_helper'

describe Spree::StockMovement do
  let(:stock_item) { create(:stock_item) }
  let(:variant) { stock_item.variant }
  let(:stock_movement) { create(:stock_movement, stock_item: stock_item, quantity: quantity) }
  let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant).serializable_hash.to_json }

  describe '#update_stock_item_quantity' do
    subject { stock_movement }

    describe 'when the variant goes out of stock' do
      let(:quantity) { -stock_item.count_on_hand }

      it 'emits the variant.out_of_stock event' do
        expect { Timecop.freeze { subject } }.to emit_webhook_event('variant.out_of_stock')
      end
    end

    describe 'when the variant does not go out of stock' do
      let(:quantity) { -stock_item.count_on_hand + 1 }

      it 'does not emit the variant.out_of_stock event' do
        expect { subject }.not_to emit_webhook_event('variant.out_of_stock')
      end
    end
  end
end
