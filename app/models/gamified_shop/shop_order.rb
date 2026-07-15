# frozen_string_literal: true

module GamifiedShop
  class ShopOrder < ActiveRecord::Base
    self.table_name = "gamified_shop_orders"

    FULFILLED = "fulfilled"
    REFUNDED = "refunded"
    STATUSES = [FULFILLED, REFUNDED].freeze

    belongs_to :user
    belongs_to :shop_item, class_name: "GamifiedShop::ShopItem"

    validates :status, inclusion: { in: STATUSES }
    validates :price_paid, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :fulfilled, -> { where(status: FULFILLED) }
  end
end
