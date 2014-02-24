require_dependency 'spree/api/controller_setup'

module Spree
  module Api
    class BaseController < ActionController::Base
      include Spree::Api::ControllerSetup
      include Spree::Core::ControllerHelpers::SSL
      include Spree::Core::ControllerHelpers::StrongParameters

      attr_accessor :current_api_user

      before_filter :set_content_type
      before_filter :check_for_user_or_api_key, :if => :requires_authentication?
      before_filter :authenticate_user
      after_filter  :set_jsonp_format

      rescue_from Exception, :with => :error_during_processing
      rescue_from CanCan::AccessDenied, :with => :unauthorized
      rescue_from ActiveRecord::RecordNotFound, :with => :not_found

      helper Spree::Api::ApiHelpers

      ssl_allowed

      def set_jsonp_format
        if params[:callback] && request.get?
          self.response_body = "#{params[:callback]}(#{response.body})"
          headers["Content-Type"] = 'application/javascript'
        end
      end

      def map_nested_attributes_keys(klass, attributes)
        nested_keys = klass.nested_attributes_options.keys
        attributes.inject({}) do |h, (k,v)|
          key = nested_keys.include?(k.to_sym) ? "#{k}_attributes" : k
          h[key] = v
          h
        end.with_indifferent_access
      end

      # users should be able to set price when importing orders via api
      def permitted_line_item_attributes
        if current_api_user.has_spree_role?("admin")
          super << [:price, :variant_id, :sku]
        else
          super
        end
      end

      private

      def pagination(collection)
        {
         count: collection.count,
         total_count: collection.total_count,
         current_page: params[:page] ? params[:page].to_i : 1,
         per_page: params[:per_page] || Kaminari.config.default_per_page,
         pages: collection.num_pages
        }
      end

      def set_content_type
        content_type = case params[:format]
        when "json"
          "application/json"
        when "xml"
          "text/xml"
        end
        headers["Content-Type"] = content_type
      end

      def check_for_user_or_api_key
        # User is already authenticated with Spree, make request this way instead.
        return true if @current_api_user = try_spree_current_user || !Spree::Api::Config[:requires_authentication]

        if api_key.blank?
          render "spree/api/errors/must_specify_api_key", :status => 401 and return
        end
      end

      def authenticate_user
        unless @current_api_user
          if requires_authentication? || api_key.present?
            unless @current_api_user = Spree.user_class.find_by(spree_api_key: api_key.to_s)
              render "spree/api/errors/invalid_api_key", :status => 401 and return
            end
          else
            # An anonymous user
            @current_api_user = Spree.user_class.new
          end
        end
      end

      def unauthorized
        render json: { error: I18n.t(:unauthorized, :scope => "spree.api") }, status: 401
      end

      def error_during_processing(exception)
        Rails.logger.error exception.message
        Rails.logger.error exception.backtrace.join("\n")

        render :text => { :exception => exception.message }.to_json,
          :status => 422 and return
      end

      def requires_authentication?
        Spree::Api::Config[:requires_authentication]
      end

      def not_found
        render json: { error: I18n.t(:resource_not_found, :scope => "spree.api") }, status: 404
      end

      def current_ability
        Spree::Ability.new(current_api_user)
      end

      def current_currency
        Spree::Config[:currency]
      end
      helper_method :current_currency

      def invalid_resource!(resource)
        render json: {
          error: I18n.t(:invalid_resource, :scope => "spree.api"),
          errors: resource.errors
        }, status: 422 
      end

      def api_key
        request.headers["X-Spree-Token"] || params[:token]
      end
      helper_method :api_key

      def find_product(id)
        begin
          product_scope.friendly.find(id.to_s)
        rescue ActiveRecord::RecordNotFound
          product_scope.find(id)
        end
      end

      def product_scope
        variants_associations = [{ option_values: :option_type }, :default_price, :prices, :images]
        if current_api_user.has_spree_role?("admin")
          scope = Product.with_deleted.accessible_by(current_ability, :read)
            .includes(:properties, :option_types, variants: variants_associations, master: variants_associations)

          unless params[:show_deleted]
            scope = scope.not_deleted
          end
        else
          scope = Product.accessible_by(current_ability, :read).active
            .includes(:properties, :option_types, variants: variants_associations, master: variants_associations)
        end

        scope
      end
    end
  end
end
