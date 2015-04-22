module Spree
  module Api
    module V2
      class PaymentsController < Spree::Api::BaseController
        before_action :find_order
        before_action :find_payment, only: [:update, :show, :authorize, :purchase, :capture, :void]

        def index
          @payments = @order.payments.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          render json: @payments, meta: pagination(@payments)
        end

        def new
          @payment_methods = Spree::PaymentMethod.available
          render json: { payment_methods: @payment_methods }
        end

        def create
          @payment = @order.payments.build(payment_params)
          if @payment.save
            render json: @payment, status: 201
          else
            invalid_resource!(@payment)
          end
        end

        def update
          authorize! params[:action], @payment
          if ! @payment.pending?
            render json: {
              error: I18n.t(
                :update_forbidden,
                state: @payment.state,
                scope: 'spree.api.payment'
              )
            }, status: 403
          elsif @payment.update_attributes(payment_params)
            render json: @payment
          else
            invalid_resource!(@payment)
          end
        end

        def show
          render json: @payment
        end

        def authorize
          perform_payment_action(:authorize)
        end

        def capture
          perform_payment_action(:capture)
        end

        def purchase
          perform_payment_action(:purchase)
        end

        def void
          perform_payment_action(:void_transaction)
        end

        private

        def find_order
          @order = Spree::Order.friendly.find(order_id)
          authorize! :read, @order, order_token
        end

        def find_payment
          @payment = @order.payments.friendly.find(params[:id])
        end

        def perform_payment_action(action, *args)
          authorize! action, Payment
          @payment.send("#{action}!", *args)
          render json: @payment, default_template: :show
        end

        def payment_params
          params.require(:payment).permit(permitted_payment_attributes)
        end
      end
    end
  end
end
