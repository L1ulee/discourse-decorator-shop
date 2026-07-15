# frozen_string_literal: true

module GamifiedShop
  class ApplicationController < ::ApplicationController
    requires_plugin GamifiedShop::PLUGIN_NAME

    before_action :ensure_logged_in

    rescue_from GamifiedShop::ShopError do |error|
      render_json_error(I18n.t("gamified_shop.errors.#{error.code}"), status: 422)
    end
  end
end
