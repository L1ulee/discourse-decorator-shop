# frozen_string_literal: true

# name: discourse-decorator-shop
# about: Gamified decoration shop - self-owned point economy plus a store for avatar frames, username styles and user card backgrounds.
# version: 0.1.0
# authors: L1ulee
# url: https://github.com/L1ulee/discourse-decorator-shop
# required_version: 2.7.0

enabled_site_setting :gamified_shop_enabled

register_asset "stylesheets/common/gamified-shop.scss"
register_asset "stylesheets/common/gamified-shop-pages.scss"

module ::GamifiedShop
  PLUGIN_NAME = "discourse-decorator-shop"
end

require_relative "lib/gamified_shop/engine"

after_initialize do
  # --- Earning events (PRD 6.2) ---

  on(:topic_created) { |topic, _opts, user| GamifiedShop::Earnings.topic_created(topic, user) }

  on(:post_created) { |post, _opts, user| GamifiedShop::Earnings.reply_created(post, user) }

  on(:like_created) { |post_action, *| GamifiedShop::Earnings.like_created(post_action) }

  on(:like_destroyed) { |post_action, *| GamifiedShop::Earnings.like_destroyed(post_action) }

  on(:post_destroyed) { |post, _opts, _user| GamifiedShop::Earnings.post_destroyed(post) }

  on(:post_recovered) { |post, _opts, _user| GamifiedShop::Earnings.post_recovered(post) }

  on(:topic_destroyed) { |topic, _user| GamifiedShop::Earnings.topic_destroyed(topic) }

  on(:topic_recovered) { |topic, _user| GamifiedShop::Earnings.topic_recovered(topic) }

  # --- Serializer data (PRD 12) ---
  # Post stream: equipped asset ids only; CSS classes drive the rendering.
  # The include_condition must NOT reference `object` (an object-referencing
  # condition here evaluates false/absent on the post stream, unlike the
  # object-free :user/:user_card conditions below); guard the user_id in the
  # value block instead.
  add_to_serializer(
    :post,
    :gamified_shop,
    include_condition: -> { SiteSetting.gamified_shop_enabled },
  ) { object.user_id ? GamifiedShop::EquippedCache.for_user(object.user_id) : {} }

  # User card and full profile: equipped asset ids + public balance.
  add_to_serializer(
    :user_card,
    :gamified_shop,
    include_condition: -> { SiteSetting.gamified_shop_enabled },
  ) do
    GamifiedShop::EquippedCache.for_user(object.id).merge(
      "balance" => GamifiedShop::PointAccount.balance_for(object.id),
    )
  end

  add_to_serializer(
    :user,
    :gamified_shop,
    include_condition: -> { SiteSetting.gamified_shop_enabled },
  ) do
    GamifiedShop::EquippedCache.for_user(object.id).merge(
      "balance" => GamifiedShop::PointAccount.balance_for(object.id),
    )
  end

  # --- Compiled decoration stylesheet (ADR-0002) ---
  register_html_builder("server:before-head-close") do |_controller|
    if SiteSetting.gamified_shop_enabled
      digest = GamifiedShop::StylesheetCompiler.digest
      "<link rel=\"stylesheet\" href=\"#{Discourse.base_path}/gamified-shop/stylesheet/#{digest}.css\" data-gamified-shop=\"true\">"
    else
      ""
    end
  end

  # --- Routes ---
  Discourse::Application.routes.append do
    mount ::GamifiedShop::Engine, at: "/gamified-shop"

    scope "/admin/plugins/gamified-shop" do
      # Admin-only (items, orders, ledger): moderators fail the constraint and
      # get a routing 404, so these endpoints stay hidden rather than leaking
      # their existence with a 403. Controllers still inherit
      # ::Admin::AdminController as defense in depth.
      constraints(AdminConstraint.new) do
        get "/items" => "gamified_shop/admin/items#index"
        post "/items" => "gamified_shop/admin/items#create"
        put "/items/:id" => "gamified_shop/admin/items#update"

        get "/orders" => "gamified_shop/admin/orders#index"
        post "/orders/:id/refund" => "gamified_shop/admin/orders#refund"

        get "/ledger" => "gamified_shop/admin/ledger#index"
      end

      # Staff-reachable (assets, user grants); finer per-action checks
      # (admin-only custom CSS, moderator grant setting) live in the controllers.
      constraints(StaffConstraint.new) do
        get "/assets" => "gamified_shop/admin/assets#index"
        post "/assets" => "gamified_shop/admin/assets#create"
        delete "/assets/:id" => "gamified_shop/admin/assets#destroy"

        get "/users" => "gamified_shop/admin/users#index"
        get "/users/:user_id" => "gamified_shop/admin/users#show"
        post "/users/:user_id/points" => "gamified_shop/admin/users#adjust_points"
        post "/users/:user_id/decorations" => "gamified_shop/admin/users#grant_decoration"
        delete "/users/:user_id/decorations/:id" => "gamified_shop/admin/users#revoke_decoration"
      end
    end
  end

  add_admin_route "gamified_shop.admin.title", "gamified-shop"
end
