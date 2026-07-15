# frozen_string_literal: true

module GamifiedShop
  module Admin
    # Staff-reachable endpoints (assets, user grants); finer permission
    # checks (admin-only custom CSS, moderator grant setting) happen
    # per-action.
    class StaffController < ::Admin::StaffController
      requires_plugin GamifiedShop::PLUGIN_NAME

      before_action :serve_app_shell_for_html

      rescue_from GamifiedShop::ShopError do |error|
        render_json_error(I18n.t("gamified_shop.errors.#{error.code}"), status: 422)
      end

      private

      # See GamifiedShop::Admin::AdminController: HTML reloads of tab URLs
      # boot the Ember admin app instead of dumping JSON.
      def serve_app_shell_for_html
        render "default/empty" if request.format.html?
      end
    end
  end
end
