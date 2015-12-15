require 'spec_helper'

# rubocop:disable ModuleLength
module Spree
  module Core
    describe Importer::Order do
      let!(:store) { create(:store, default: true) }

      let!(:store)          { create(:store, default: true)    }
      let!(:country)        { create(:country)                 }
      let!(:state)          { create(:state, country: country) }
      let(:address)         { build(:address, state: state)    }
      let!(:stock_location) { create(:stock_location)          }
      let(:user)            { create(:user)                    }
      let(:shipping_method) { create(:shipping_method)         }
      let(:payment_method)  { create(:check_payment_method)    }
      let(:sku)             { variant.sku                      }
      let(:variant_id)      { variant.id                       }

      let(:product) {
        Spree::Product.create!(
          name:              'Test',
          sku:               'TEST-1',
          price:             33.22,
          shipping_category: create(:shipping_category)
        )
      }

      let(:variant) do
        variant = product.master
        variant.stock_items.each do |stock_item|
          stock_item.update_attribute(:count_on_hand, 10)
        end
        variant
      end

      let(:line_items) do
        {
          '0' => {
            variant_id: variant.id,
            quantity:   5
          }
        }
      end

      let(:ship_address) do
        HashWithIndifferentAccess
          .new(address.attributes)
          .except(*%i[id created_at updated_at])
      end

      it 'can import an order number' do
        params = { number: '123-456-789' }
        order = Importer::Order.import(user, params)
        expect(order.number).to eq '123-456-789'
      end

      it 'optionally add completed at' do
        params = { email: 'test@test.com',
                   completed_at: Time.now,
                   line_items_attributes: line_items }

        order = Importer::Order.import(user,params)
        expect(order).to be_completed
        expect(order.state).to eq 'complete'
      end

      it "assigns order[email] over user email to order" do
        params = { email: 'wooowww@test.com' }
        order = Importer::Order.import(user,params)
        expect(order.email).to eq params[:email]
      end

      context "assigning a user to an order" do
        let(:other_user) { stub_model(LegacyUser, :email => 'dana@scully.com') }

        context "as an admin" do
          before { allow(user).to receive_messages :has_spree_role? => true }

          context "a user's id is not provided" do
            # this is a regression spec for an issue we ran into at Bonobos
            it "doesn't unassociate the admin from the order" do
              params = { }
              order = Importer::Order.import(user, params)
              expect(order.user_id).to eq(user.id)
            end
          end
        end

        context "as a user" do
          before { allow(user).to receive_messages :has_spree_role? => false }
          it "does not assign the order to the other user" do
            params = { user_id: other_user.id }
            order = Importer::Order.import(user, params)
            expect(order.user_id).to eq(user.id)
          end
        end
      end

      it 'can build an order from API with just line items' do
        params = { :line_items_attributes => line_items }

        expect(Importer::Order).to receive(:ensure_variant_id_from_params).and_return({variant_id: variant.id, quantity: 5})
        order = Importer::Order.import(user,params)
        expect(order.user).to eql(user)
        line_item = order.line_items.first!
        expect(line_item.quantity).to eq(5)
        expect(line_item.variant_id).to eq(variant_id)
      end

      it 'handles line_item building exceptions' do
        line_items['0'][:variant_id] = 'XXX'
        params = { :line_items_attributes => line_items }

        expect {
          order = Importer::Order.import(user,params)
        }.to raise_error /XXX/
      end

      it 'handles line_item updating exceptions' do
        line_items['0'][:currency] = 'GBP'
        params = { :line_items_attributes => line_items }

        expect {
          order = Importer::Order.import(user, params)
        }.to raise_error /Validation failed/
      end

      it 'can build an order from API with variant sku' do
        params = { :line_items_attributes => {
                     "0" => { :sku => sku, :quantity => 5 } }}

        order = Importer::Order.import(user,params)

        line_item = order.line_items.first!
        expect(line_item.variant_id).to eq(variant_id)
        expect(line_item.quantity).to eq(5)
      end

      it 'handles exceptions when sku is not found' do
        params = { :line_items_attributes => {
                     "0" => { :sku => 'XXX', :quantity => 5 } }}
        expect {
          order = Importer::Order.import(user,params)
        }.to raise_error /XXX/
      end

      it 'can build an order from API shipping address' do
        params = {
          ship_address_attributes: ship_address,
          line_items_attributes:   line_items
        }

        order = Importer::Order.import(user, params)

        expect(order.ship_address.address1).to eql(address.address1)
      end

      it 'can build an order from API with country attributes' do
        ship_address.delete(:country_id)
        ship_address[:country] = { 'iso' => country.iso }

        params = {
          ship_address_attributes: ship_address,
          line_items_attributes:   line_items
        }

        order = Importer::Order.import(user, params)

        expect(order.ship_address.country.iso).to eql(country.iso)
      end

      it 'handles country lookup exceptions' do
        ship_address.delete(:country_id)
        ship_address[:country] = { 'iso' => 'XXX' }
        params = { :ship_address_attributes => ship_address,
                   :line_items_attributes => line_items }

        expect {
          order = Importer::Order.import(user,params)
        }.to raise_error /XXX/
      end

      it 'can build an order from API with state attributes' do
        ship_address.delete(:state_id)
        ship_address[:state] = { 'name' => state.name }
        params = { :ship_address_attributes => ship_address,
                   :line_items_attributes => line_items }

        order = Importer::Order.import(user,params)
        expect(order.ship_address.state.name).to eql(state.name)
      end

      context "with a different currency" do
        before { variant.price_in("GBP").update_attribute(:price, 18.99) }

        it "sets the order currency" do
          params = {
            currency: "GBP"
          }
          order = Importer::Order.import(user,params)
          expect(order.currency).to eq "GBP"
        end

        it "can handle it when a line order price is specified" do
          params = {
            currency: "GBP",
            line_items_attributes: line_items
          }
          line_items["0"].merge! currency: "GBP", price: 1.99
          order = Importer::Order.import(user, params)
          expect(order.currency).to eq "GBP"
          expect(order.line_items.first.price).to eq 1.99
          expect(order.line_items.first.currency).to eq "GBP"
        end
      end

      context 'state passed is not associated with country' do
        let(:params) do
          {
            ship_address_attributes: ship_address,
            line_items_attributes:   line_items
          }
        end

        let(:other_state) do
          create(:state, country: create(:country))
        end

        before do
          ship_address.delete(:state_id)
          ship_address[:state] = { 'name' => other_state.name }
        end

        it 'fails with invalid address state' do
          expect { Importer::Order.import(user, params) }.to raise_error(
            ActiveRecord::RecordInvalid,
            'Validation failed: Shipping address state is invalid'
          )
        end
      end

      it 'fails if state record not found' do
        ship_address.delete(:state_id)

        ship_address[:state] = { 'name' => 'XXX' }

        params = {
          ship_address_attributes: ship_address,
          line_items_attributes:   line_items
        }

        expect { Importer::Order.import(user, params) }.to raise_error(
          ActiveRecord::RecordInvalid,
          'Validation failed: Shipping address state is invalid'
        )
      end

      context 'variant not deleted' do
        it 'ensures variant id from api' do
          hash = { sku: variant.sku }
          Importer::Order.ensure_variant_id_from_params(hash)
          expect(hash[:variant_id]).to eq variant.id
        end
      end

      context 'variant was deleted' do
        it 'raise error as variant shouldnt be found' do
          variant.product.destroy
          hash = { sku: variant.sku }
          expect {
            Importer::Order.ensure_variant_id_from_params(hash)
          }.to raise_error
        end
      end

      it 'ensures_country_id for country fields' do
        [:name, :iso, :iso_name, :iso3].each do |field|
          address = { :country => { field => country.send(field) }}
          Importer::Order.ensure_country_id_from_params(address)
          expect(address[:country_id]).to eq country.id
        end
      end

      it "raises with proper message when cant find country" do
        address = { :country => { "name" => "NoNoCountry" } }
        expect {
          Importer::Order.ensure_country_id_from_params(address)
        }.to raise_error /NoNoCountry/
      end

      it 'ensures_state_id for state fields' do
        [:name, :abbr].each do |field|
          address = { country_id: country.id, :state => { field => state.send(field) }}
          Importer::Order.ensure_state_id_from_params(address)
          expect(address[:state_id]).to eq state.id
        end
      end

      context "shipments" do
        let(:params) do
          { :line_items_attributes => line_items,
            :shipments_attributes => [
              { :tracking => '123456789',
                :cost => '14.99',
                :shipping_method => shipping_method.name,
                :stock_location => stock_location.name,
                :inventory_units => [{ :sku => sku }]
              }
          ] }
        end

        it 'ensures variant exists and is not deleted' do
          expect(Importer::Order).to receive(:ensure_variant_id_from_params)
            .twice.and_call_original
          order = Importer::Order.import(user,params)
        end

        it 'builds them properly' do
          order = Importer::Order.import(user, params)
          shipment = order.shipments.first!

          expect(shipment.cost.to_f).to eq 14.99
          expect(shipment.inventory_units.first!.variant_id).to eq product.master.id
          expect(shipment.tracking).to eq '123456789'
          expect(shipment.shipping_rates.first!.cost).to eq 14.99
          expect(shipment.selected_shipping_rate).to eq(shipment.shipping_rates.first)
          expect(shipment.stock_location).to eq stock_location
          expect(order.shipment_total.to_f).to eq 14.99
        end

        it "accepts admin name for stock location" do
          params[:shipments_attributes][0][:stock_location] = stock_location.admin_name
          order = Importer::Order.import(user, params)
          shipment = order.shipments.first!

          expect(shipment.stock_location).to eq stock_location
        end

        it "raises if cant find stock location" do
          params[:shipments_attributes][0][:stock_location] = "doesnt exist"
          expect {
            order = Importer::Order.import(user,params)
          }.to raise_error
        end

        context 'when completed_at and shipped_at present' do
          let(:params) do
            {
              :completed_at => 2.days.ago,
              :line_items_attributes => line_items,
              :shipments_attributes => [
                { :tracking => '123456789',
                  :cost => '4.99',
                  :shipped_at => 1.day.ago,
                  :shipping_method => shipping_method.name,
                  :stock_location => stock_location.name,
                  :inventory_units => [{ :sku => sku }]
                }
              ]
            }
          end

          it 'builds them properly' do
            order = Importer::Order.import(user, params)
            shipment = order.shipments.first!

            expect(shipment.cost.to_f).to eq 4.99
            expect(shipment.inventory_units.first!.variant_id).to eq product.master.id
            expect(shipment.tracking).to eq '123456789'
            expect(shipment.shipped_at).to be_present
            expect(shipment.shipping_rates.first!.cost).to eq 4.99
            expect(shipment.selected_shipping_rate).to eq(shipment.shipping_rates.first)
            expect(shipment.stock_location).to eq stock_location
            expect(shipment.state).to eq('shipped')
            expect(shipment.inventory_units.all?(&:shipped?)).to be true
            expect(order.shipment_state).to eq('shipped')
            expect(order.shipment_total.to_f).to eq 4.99
          end
        end
      end

      it 'handles shipment building exceptions' do
        params = { :shipments_attributes => [{ tracking: '123456789',
                                               cost: '4.99',
                                               shipping_method: 'XXX',
                                               inventory_units: [{ sku: sku }]
                                             }] }
        expect {
          order = Importer::Order.import(user,params)
        }.to raise_error /XXX/
      end

      it 'adds adjustments' do
        params = { :adjustments_attributes => [
            { label: 'Shipping Discount', amount: -4.99 },
            { label: 'Promotion Discount', amount: -3.00 }] }

        order = Importer::Order.import(user,params)
        order.adjustments.all?(&:closed?).should be(true)
        first = order.adjustments.first
        expect(first.label).to eql('Shipping Discount')
        expect(first.amount).to eql(-4.99)
      end

      it "calculates final order total correctly" do
        params = {
          adjustments_attributes: [
            { label: 'Promotion Discount', amount: -3.00 }
          ],
          line_items_attributes: {
            "0" => {
              variant_id: variant.id,
              quantity: 5
            }
          }
        }

        order = Importer::Order.import(user,params)
        expect(order.item_total).to eq(166.1)
        expect(order.total).to eq(163.1) # = item_total (166.1) - adjustment_total (3.00)

      end

      it 'handles adjustment building exceptions' do
        params = { :adjustments_attributes => [
            { amount: 'XXX' },
            { label: 'Promotion Discount', amount: '-3.00' }] }

        expect {
          order = Importer::Order.import(user,params)
        }.to raise_error /XXX/
      end

      it 'builds a payment using state' do
        params = { :payments_attributes => [{ amount: '4.99',
                                              payment_method: payment_method.name,
                                              state: 'completed' }] }
        order = Importer::Order.import(user,params)
        expect(order.payments.first!.amount).to eq 4.99
      end

      it 'builds a payment using status as fallback' do
        params = { :payments_attributes => [{ amount: '4.99',
                                              payment_method: payment_method.name,
                                              status: 'completed' }] }
        order = Importer::Order.import(user,params)
        expect(order.payments.first!.amount).to eq 4.99
      end

      it 'handles payment building exceptions' do
        params = { :payments_attributes => [{ amount: '4.99',
                                              payment_method: 'XXX' }] }
        expect {
          order = Importer::Order.import(user, params)
        }.to raise_error /XXX/
      end

      it 'build a source payment using years and month' do
        params = { :payments_attributes => [{
                                              amount: '4.99',
                                              payment_method: payment_method.name,
                                              status: 'completed',
                                              source: {
                                                name: 'Fox',
                                                last_digits: "7424",
                                                cc_type: "visa",
                                                year: '2022',
                                                month: "5"
                                              }
                                            }]}

        order = Importer::Order.import(user, params)
        expect(order.payments.first!.source.last_digits).to eq '7424'
      end

      it 'handles source building exceptions when do not have years and month' do
        params = { :payments_attributes => [{
                                              amount: '4.99',
                                              payment_method: payment_method.name,
                                              status: 'completed',
                                              source: {
                                                name: 'Fox',
                                                last_digits: "7424",
                                                cc_type: "visa"
                                              }
                                            }]}

        expect {
          order = Importer::Order.import(user, params)
        }.to raise_error /Validation failed: Credit card Month is not a number, Credit card Year is not a number/
      end
    end
  end
end
