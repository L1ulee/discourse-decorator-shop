# frozen_string_literal: true

module GamifiedShop
  class PointLedgerEntry < ActiveRecord::Base
    self.table_name = "gamified_shop_point_ledger_entries"

    ADMIN_GRANT = "admin_grant"
    ADMIN_DEDUCT = "admin_deduct"
    EVENT_REWARD = "event_reward"
    EVENT_REVERSAL = "event_reversal"
    PURCHASE_SPEND = "purchase_spend"
    PURCHASE_REFUND = "purchase_refund"
    SYSTEM_ADJUSTMENT = "system_adjustment"

    TYPES = [
      ADMIN_GRANT,
      ADMIN_DEDUCT,
      EVENT_REWARD,
      EVENT_REVERSAL,
      PURCHASE_SPEND,
      PURCHASE_REFUND,
      SYSTEM_ADJUSTMENT,
    ].freeze

    belongs_to :user

    validates :entry_type, inclusion: { in: TYPES }
    validates :amount, numericality: { only_integer: true, other_than: 0 }

    # The ledger is immutable and append-only (PRD 6.1, ADR-0003).
    before_destroy { raise ActiveRecord::ReadOnlyRecord, "ledger entries cannot be deleted" }
    before_update { raise ActiveRecord::ReadOnlyRecord, "ledger entries cannot be updated" }

    def self.earned_today(user_id)
      where(user_id: user_id, entry_type: EVENT_REWARD).where(
        "created_at >= ?",
        Time.zone.now.beginning_of_day,
      ).sum(:amount)
    end
  end
end
