# frozen_string_literal: true

module GamifiedShop
  module Admin
    # Admin-only endpoints (items, orders, ledger).
    class AdminController < ::Admin::AdminController
      requires_plugin GamifiedShop::PLUGIN_NAME

      before_action :serve_app_shell_for_html

      rescue_from GamifiedShop::ShopError do |error|
        render_json_error(I18n.t("gamified_shop.errors.#{error.code}"), status: 422)
      end

      private

      # The admin tab URLs double as JSON API paths; a browser reload /
      # deep link arrives as HTML and should boot the Ember admin app
      # instead of dumping JSON.
      def serve_app_shell_for_html
        render "default/empty" if request.format.html?
      end
    end
  end
end
