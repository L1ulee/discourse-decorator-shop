# frozen_string_literal: true

module GamifiedShop
  class PointLedgerEntrySerializer < ApplicationSerializer
    attributes :id,
               :user_id,
               :username,
               :amount,
               :balance_after,
               :entry_type,
               :reference_type,
               :reference_id,
               :description,
               :created_by_id,
               :created_at

    # Falls back to the raw id so a deleted user still identifies the account.
    def username
      object.user&.username || "##{object.user_id}"
    end
  end
end
