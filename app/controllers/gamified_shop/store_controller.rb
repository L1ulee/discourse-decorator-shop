# frozen_string_literal: true

module GamifiedShop
  class StoreController < ApplicationController
    def index
      items = ShopItem.listed.includes(decoration_asset: :upload).order(:id)

      purchased_counts =
        ShopOrder
          .fulfilled
          .where(user_id: current_user.id, shop_item_id: items.map(&:id))
          .group(:shop_item_id)
          .count
      owned_asset_ids =
        UserDecoration
          .not_expired
          .where(user_id: current_user.id)
          .distinct
          .pluck(:decoration_asset_id)

      render_json_dump(
        items: serialize_data(items, ShopItemSerializer),
        balance: PointAccount.balance_for(current_user.id),
        currency_name: SiteSetting.gamified_shop_currency_name,
        purchased_counts: purchased_counts,
        owned_asset_ids: owned_asset_ids,
      )
    end
  end
end
