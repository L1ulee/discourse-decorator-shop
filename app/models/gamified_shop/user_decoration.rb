# frozen_string_literal: true

module GamifiedShop
  class UserDecoration < ActiveRecord::Base
    self.table_name = "gamified_shop_user_decorations"

    PURCHASE = "purchase"
    ADMIN_GRANT = "admin_grant"
    SOURCES = [PURCHASE, ADMIN_GRANT].freeze

    belongs_to :user
    belongs_to :decoration_asset, class_name: "GamifiedShop::DecorationAsset"

    validates :source, inclusion: { in: SOURCES }

    # States are derived facts, never stored (PRD 6.5):
    # displayable <=> equipped AND not expired.
    scope :not_expired, -> { where("expires_at IS NULL OR expires_at > ?", Time.zone.now) }
    scope :displayable, -> { where(equipped: true).not_expired }

    after_commit { GamifiedShop::EquippedCache.invalidate(user_id) }

    def expired?
      expires_at.present? && expires_at <= Time.zone.now
    end

    def displayable?
      equipped? && !expired?
    end
  end
end
