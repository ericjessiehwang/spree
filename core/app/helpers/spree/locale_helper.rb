module Spree
  module LocaleHelper
    def all_locales_options
      supported_locales_for_all_stores.map { |locale| locale_presentation(locale) }
    end

    def available_locales_options
      available_locales.map { |locale| locale_presentation(locale) }
    end

    def supported_locales_options
      return if current_store.nil?

      current_store.supported_locales_list.map { |locale| locale_presentation(locale) }
    end

    def locale_presentation(locale)
      formatted_locale = locale.to_s

      if I18n.exists?('spree.i18n.this_file_language', locale: formatted_locale, fallback: false)
        [Spree.t('i18n.this_file_language', locale: formatted_locale), formatted_locale]
      else
        [formatted_locale, formatted_locale]
      end
    end

    def should_render_locale_dropdown?
      return false if current_store.nil?

      current_store.supported_locales_list.size > 1
    end
  end
end
