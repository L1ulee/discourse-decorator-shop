# frozen_string_literal: true

module GamifiedShop
  class ShopItem < ActiveRecord::Base
    self.table_name = "gamified_shop_items"

    DECORATION = "decoration"
    ITEM_TYPES = [DECORATION].freeze

    belongs_to :decoration_asset,
               class_name: "GamifiedShop::DecorationAsset",
               optional: true
    has_many :orders, class_name: "GamifiedShop::ShopOrder", foreign_key: :shop_item_id

    validates :name, presence: true, length: { maximum: 200 }
    validates :item_type, inclusion: { in: ITEM_TYPES }
    validates :price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :stock,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 },
              allow_nil: true
    validates :purchase_limit_per_user,
              numericality: { only_integer: true, greater_than: 0 },
              allow_nil: true
    validate :decoration_asset_required_when_listed

    scope :listed, -> { where(listed: true) }

    # Atomic conditional stock claim (ADR-0003): stock = NULL means unlimited.
    # Returns true when a unit was claimed (or stock is unlimited).
    def self.claim_stock!(item_id)
      where(id: item_id)
        .where("stock IS NULL OR stock > 0")
        .update_all(
          "stock = CASE WHEN stock IS NULL THEN NULL ELSE stock - 1 END, updated_at = NOW()",
        ) > 0
    end

    # Refund puts the unit back into the pool (no-op for unlimited stock).
    def self.release_stock!(item_id)
      where(id: item_id)
        .where.not(stock: nil)
        .update_all("stock = stock + 1, updated_at = NOW()")
    end

    private

    def decoration_asset_required_when_listed
      if item_type == DECORATION && decoration_asset_id.blank?
        errors.add(:decoration_asset_id, :blank)
      end
    end
  end
end
