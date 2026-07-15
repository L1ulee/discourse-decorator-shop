# frozen_string_literal: true

module GamifiedShop
  class PointAccount < ActiveRecord::Base
    self.table_name = "gamified_shop_point_accounts"

    belongs_to :user

    validates :user_id, presence: true, uniqueness: true

    # Every money operation must go through this lock (ADR-0003). Must be
    # called inside a transaction; serializes all fund movements per user.
    def self.lock_for(user_id)
      ensure_exists!(user_id)
      where(user_id: user_id).lock("FOR UPDATE").first
    end

    def self.ensure_exists!(user_id)
      return if exists?(user_id: user_id)
      now = Time.zone.now
      insert_all(
        [{ user_id: user_id, balance: 0, created_at: now, updated_at: now }],
        unique_by: :user_id,
      )
    end

    def self.balance_for(user_id)
      where(user_id: user_id).pick(:balance) || 0
    end
  end
end
