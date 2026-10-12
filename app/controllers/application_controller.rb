class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :switch_locale

  private
    # Russian unless the visitor picked another language (there are no accounts, so the choice lives in a cookie).
    def switch_locale(&action)
      locale = cookies[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
      I18n.with_locale(locale, &action)
    end
end
