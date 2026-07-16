# frozen_string_literal: true

module GamifiedShop
  # Manual point adjustments and decoration grants/revokes. Admins always;
  # moderators only when gamified_shop_allow_moderator_grants is on
  # (PRD 5.3). Every action lands in the staff action log.
  class Grants
    def self.ensure_can_grant!(acting_user)
      return if acting_user&.admin?
      return if acting_user&.moderator? && SiteSetting.gamified_shop_allow_moderator_grants
      raise Discourse::InvalidAccess.new
    end

    def self.adjust_points!(user:, amount:, acting_user:, description: nil)
      ensure_can_grant!(acting_user)
      amount = amount.to_i
      raise ShopError.new(:invalid_amount) if amount.zero?
      # Deduction is an admin duty (PRD 5.2); the moderator setting only
      # unlocks issuance (PRD 5.3).
      raise Discourse::InvalidAccess.new if amount.negative? && !acting_user&.admin?

      entry_type = amount.positive? ? PointLedgerEntry::ADMIN_GRANT : PointLedgerEntry::ADMIN_DEDUCT
      entry =
        PointsLedger.apply!(
          user_id: user.id,
          amount: amount,
          entry_type: entry_type,
          description: description,
          created_by_id: acting_user.id,
        )
      StaffActionLogger.new(acting_user).log_custom(
        "gamified_shop_adjust_points",
        target_user_id: user.id,
        amount: amount,
        description: description,
      )
      entry
    end

    def self.grant_decoration!(user:, decoration_asset_id:, acting_user:, expires_at: nil)
      ensure_can_grant!(acting_user)
      asset = DecorationAsset.find_by(id: decoration_asset_id)
      raise ShopError.new(:asset_not_found) if asset.blank?

      decoration =
        UserDecoration.create!(
          user_id: user.id,
          decoration_asset_id: asset.id,
          source: UserDecoration::ADMIN_GRANT,
          source_id: acting_user.id,
          equipped: false,
          expires_at: expires_at,
        )
      StaffActionLogger.new(acting_user).log_custom(
        "gamified_shop_grant_decoration",
        target_user_id: user.id,
        decoration_asset_id: asset.id,
        expires_at: expires_at,
      )
      decoration
    end

    # Revoke = expire now (PRD 6.5); who/when goes to the staff action log.
    # Admin-only: the moderator setting covers issuance, not removal
    # (PRD 5.2/5.3).
    def self.revoke_decoration!(user_decoration_id:, acting_user:)
      raise Discourse::InvalidAccess.new unless acting_user&.admin?
      decoration = UserDecoration.find_by(id: user_decoration_id)
      raise ShopError.new(:decoration_not_found) if decoration.blank?

      decoration.update!(equipped: false, expires_at: Time.zone.now) unless decoration.expired?
      StaffActionLogger.new(acting_user).log_custom(
        "gamified_shop_revoke_decoration",
        target_user_id: decoration.user_id,
        decoration_asset_id: decoration.decoration_asset_id,
      )
      decoration
    end
  end
end
