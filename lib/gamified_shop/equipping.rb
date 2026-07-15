# frozen_string_literal: true

module GamifiedShop
  # Equip/unequip (PRD 6.5): one decoration per slot, equipping into an
  # occupied slot replaces the incumbent in the same transaction.
  class Equipping
    def self.equip!(user:, user_decoration_id:)
      target = nil
      UserDecoration.transaction do
        # Serialize equip operations per user.
        UserDecoration.where(user_id: user.id).lock("FOR UPDATE").ids

        target = UserDecoration.find_by(id: user_decoration_id, user_id: user.id)
        raise ShopError.new(:decoration_not_found) if target.blank?
        raise ShopError.new(:decoration_expired) if target.expired?

        slot = target.decoration_asset.slot
        UserDecoration
          .where(user_id: user.id, equipped: true)
          .where.not(id: target.id)
          .joins(:decoration_asset)
          .where(gamified_shop_decoration_assets: { slot: slot })
          .update_all(equipped: false, updated_at: Time.zone.now)

        target.update!(equipped: true)
      end
      EquippedCache.invalidate(user.id)
      target
    end

    def self.unequip!(user:, user_decoration_id:)
      target = UserDecoration.find_by(id: user_decoration_id, user_id: user.id)
      raise ShopError.new(:decoration_not_found) if target.blank?
      target.update!(equipped: false)
      EquippedCache.invalidate(user.id)
      target
    end
  end
end
