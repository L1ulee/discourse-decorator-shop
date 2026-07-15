# frozen_string_literal: true

module GamifiedShop
  # The single primitive every fund movement goes through (ADR-0003):
  # lock the user's account row, append one immutable ledger entry, update the
  # cached balance in the same transaction. When a block is given it is called
  # under the lock and must return the final amount (nil aborts as a no-op) -
  # used by the daily earn cap, which must be computed serially.
  class PointsLedger
    def self.apply!(
      user_id:,
      entry_type:,
      amount: nil,
      reference: nil,
      description: nil,
      created_by_id: nil
    )
      PointAccount.transaction do
        account = PointAccount.lock_for(user_id)
        final_amount = block_given? ? yield(account) : amount
        next nil if final_amount.nil? || final_amount.zero?

        new_balance = account.balance + final_amount
        entry =
          PointLedgerEntry.create!(
            user_id: user_id,
            amount: final_amount,
            balance_after: new_balance,
            entry_type: entry_type,
            reference_type: reference&.class&.name,
            reference_id: reference&.id,
            description: description,
            created_by_id: created_by_id,
            created_at: Time.zone.now,
          )
        account.update_columns(balance: new_balance, updated_at: Time.zone.now)
        entry
      end
    end
  end
end
