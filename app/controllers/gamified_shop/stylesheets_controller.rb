# frozen_string_literal: true

module GamifiedShop
  # Serves the compiled decoration stylesheet (ADR-0002). Public and
  # anonymous: guests see decorated posts too. Content-hash URLs get
  # immutable caching; anything else gets a short TTL.
  class StylesheetsController < ::ApplicationController
    requires_plugin GamifiedShop::PLUGIN_NAME

    skip_before_action :check_xhr, raise: false
    skip_before_action :preload_json, raise: false
    skip_before_action :redirect_to_login_if_required, raise: false
    skip_before_action :redirect_to_profile_if_required, raise: false
    skip_before_action :verify_authenticity_token, raise: false

    def show
      data = StylesheetCompiler.current

      if params[:digest].to_s.start_with?(data["digest"])
        response.headers["Cache-Control"] = "public, max-age=31556952, immutable"
      else
        response.headers["Cache-Control"] = "public, max-age=60"
      end

      render plain: data["css"], content_type: "text/css"
    end
  end
end
