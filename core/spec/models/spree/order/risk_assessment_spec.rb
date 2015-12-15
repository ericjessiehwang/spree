require 'spec_helper'

describe Spree::Order, :type => :model do
  let(:order) { stub_model('Spree::Order') }

  describe ".is_risky?" do
    context "Not risky order" do
      let(:order) { create(:order, payments: [payment]) }
      context "with avs_response == D" do
        let(:payment) { create(:payment, avs_response: "D") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with avs_response == M" do
        let(:payment) { create(:payment, avs_response: "M") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with avs_response == ''" do
        let(:payment) { create(:payment, avs_response: "") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with cvv_response_code == M" do
        let(:payment) { create(:payment, cvv_response_code: "M") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with cvv_response_message == ''" do
        let(:payment) { create(:payment, cvv_response_message: "") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end
    end

    context "Risky order" do
      context "AVS response message" do
        let(:order) { create(:order, payments: [create(:payment, avs_response: "A")]) }
        it "returns true if the order has an avs_response" do
          expect(order.is_risky?).to eq(true)
        end
      end

      context "CVV response code" do
        let(:order) { create(:order, payments: [create(:payment, cvv_response_code: "N")]) }
        it "returns true if the order has an cvv_response_code" do
          expect(order.is_risky?).to eq(true)
        end
      end

      context "state == 'failed'" do
        let(:order) { create(:order, payments: [create(:payment, state: 'failed')]) }
        it "returns true if the order has state == 'failed'" do
          expect(order.is_risky?).to eq(true)
        end
      end
    end
  end

  context 'is considered risky' do
    let(:order) do
      create(:completed_order_with_pending_payment).tap(&:considered_risky!)
    end

    let(:approver) { create(:user) }

    before do
      expect(order).to receive(:approve!)
    end

    it 'can be approved by a user' do
      order.approved_by(approver)
      # Yes Order#approved_by does not preserve identity :(
      expect(order.approver).to eql(approver)
      expect(order.approved_at).to be_present
      expect(order.approved?).to be(true)
    end
  end
end
