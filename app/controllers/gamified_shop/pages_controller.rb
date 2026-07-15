# frozen_string_literal: true

module GamifiedShop
  # Serves the Ember app shell for full page loads of /gamified-shop and
  # /gamified-shop/decorations; the client-side router takes over from there
  # (anonymous users are redirected by the Ember route itself).
  class PagesController < ::ApplicationController
    requires_plugin GamifiedShop::PLUGIN_NAME

    def index
      render "default/empty"
    end
  end
end
