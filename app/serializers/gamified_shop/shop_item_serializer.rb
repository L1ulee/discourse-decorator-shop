# frozen_string_literal: true

module GamifiedShop
  class ShopItemSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :description,
               :item_type,
               :price,
               :stock,
               :purchase_limit_per_user,
               :listed

    has_one :decoration_asset, serializer: DecorationAssetSerializer, embed: :objects
  end
end
