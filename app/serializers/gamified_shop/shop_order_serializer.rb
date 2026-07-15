# frozen_string_literal: true

module GamifiedShop
  class ShopOrderSerializer < ApplicationSerializer
    attributes :id,
               :user_id,
               :username,
               :shop_item_id,
               :item_name,
               :price_paid,
               :status,
               :refunded_at,
               :created_at

    def username
      object.user&.username
    end

    def item_name
      object.shop_item&.name
    end
  end
end
