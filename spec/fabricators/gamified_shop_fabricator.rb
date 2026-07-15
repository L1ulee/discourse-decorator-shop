# frozen_string_literal: true

Fabricator(:gamified_shop_decoration_asset, from: "GamifiedShop::DecorationAsset") do
  name { sequence(:gds_asset_name) { |i| "Decoration Asset #{i}" } }
  slot "username_style"
  style_preset "username_solid"
  style_params { { "color" => "#ff0000" } }
end

Fabricator(:gamified_shop_avatar_frame_asset, from: "GamifiedShop::DecorationAsset") do
  name { sequence(:gds_frame_name) { |i| "Avatar Frame #{i}" } }
  slot "avatar_frame"
  upload
end

Fabricator(:gamified_shop_card_background_asset, from: "GamifiedShop::DecorationAsset") do
  name { sequence(:gds_bg_name) { |i| "Card Background #{i}" } }
  slot "user_card_background"
  upload
end

Fabricator(:gamified_shop_item, from: "GamifiedShop::ShopItem") do
  name { sequence(:gds_item_name) { |i| "Shop Item #{i}" } }
  item_type "decoration"
  price 10
  listed true
  decoration_asset { Fabricate(:gamified_shop_decoration_asset) }
end

Fabricator(:gamified_shop_user_decoration, from: "GamifiedShop::UserDecoration") do
  user
  decoration_asset { Fabricate(:gamified_shop_decoration_asset) }
  source "admin_grant"
  source_id 1
  equipped false
end

Fabricator(:gamified_shop_order, from: "GamifiedShop::ShopOrder") do
  user
  shop_item { Fabricate(:gamified_shop_item) }
  price_paid 10
  status "fulfilled"
end
