module Spree
  class FrontendConfiguration < Preferences::Configuration
    preference :coupon_codes_enabled, :boolean, default: true # Determines if we show coupon code form at cart and checkout
    preference :locale, :string, default: Rails.application.config.i18n.default_locale
    preference :taxon_noimage_assets_path, :string, default: 'noimage/taxon_banner.jpg'
  end
end
