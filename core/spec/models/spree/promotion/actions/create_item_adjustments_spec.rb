require 'spec_helper'

module Spree
  class Promotion
    module Actions
      describe CreateItemAdjustments do
        let(:order) { Spree::Order.new }
        let(:promotion) { build(:promotion) }
        let(:action) do
          CreateItemAdjustments.new(promotion: promotion).tap do |action|
            action.stub :calculator => double('Calculator')
          end
        end
        let!(:line_item) do
          Spree::LineItem.new.tap do |line_item|
            line_item.stub(:product => double('Product', id: 999999))
          end
        end


        before do 
          order.line_items << line_item
        end

        context "#perform" do
          # Regression test for #3966
          context "when calculator computes 0" do
            before do
              action.stub :compute_amount => 0
            end

            it "does not create an adjustment when calculator returns 0" do
              action.perform(order: order)
              action.adjustments.should be_empty
            end
          end

          context "when calculator returns a non-zero value" do
            before do
              promotion.promotion_actions = [action]
              action.stub :compute_amount => 10
            end

            it "creates adjustment with item as adjustable" do
              action.perform(order: order)
              line_item.adjustments.to_a.count.should == 1
            end

            it "creates adjustment with self as source" do
              action.perform(order: order)
              expect(line_item.adjustments.first.source).to eq action
            end

            it "does not perform twice on the same item" do
              2.times { action.perform(order: order) }
              line_item.adjustments.to_a.count.should == 1
            end

            context "with products rules" do
              let!(:matching_line_item) { build(:line_item) }

              before do
                order.line_items << matching_line_item
                promotion.stub(:product_ids => [matching_line_item.product.id])
              end


              it "does not create an adjustmenty for line_items not in product rule" do
                action.perform(order: order)
                expect(matching_line_item.adjustments.to_a.count).to eql 1
                expect(line_item.adjustments.to_a.count).to eql 0
              end
            end
          end
        end

        context "#compute_amount" do
          before do 
            promotion.promotion_actions = [action]
            line_item.stub(amount: 100)
          end

          it "calls compute on the calculator" do
            action.calculator.should_receive(:compute).with(line_item)
            action.compute_amount(line_item)
          end

          context "calculator returns amount greater than item total" do
            before do
              action.calculator.should_receive(:compute).with(line_item).and_return(300)
            end

            it "does not exceed it" do
              action.compute_amount(line_item).should eql(-100)
            end
          end
        end

        context "#destroy" do
          let!(:action) { CreateItemAdjustments.create! }
          let(:other_action) { CreateItemAdjustments.create! }

          it "destroys adjustments for incompleted orders" do
            order = Order.create
            action.adjustments.create!(label: "Check", amount: 0, order: order)

            expect {
              action.destroy
            }.to change { Adjustment.count }.by(-1)
          end

          it "nullifies adjustments for completed orders" do
            order = Order.create(completed_at: Time.now)
            adjustment = action.adjustments.create!(label: "Check", amount: 0, order: order)

            expect {
              action.destroy
            }.to change { adjustment.reload.source_id }.from(action.id).to nil
          end

          it "doesnt mess with unrelated adjustments" do
            other_action.adjustments.create!(label: "Check", amount: 0)

            expect {
              action.destroy
            }.not_to change { other_action.adjustments.count }
          end
        end
      end
    end
  end
end
