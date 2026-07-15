# frozen_string_literal: true

module GamifiedShop
  class PointLedgerEntrySerializer < ApplicationSerializer
    attributes :id,
               :user_id,
               :amount,
               :balance_after,
               :entry_type,
               :reference_type,
               :reference_id,
               :description,
               :created_by_id,
               :created_at
  end
end
