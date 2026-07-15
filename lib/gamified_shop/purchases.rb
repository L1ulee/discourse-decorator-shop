# frozen_string_literal: true

module GamifiedShop
  # The purchase transaction (ADR-0003): lock account -> validate balance /
  # listing / limit -> atomic stock claim -> ledger entry -> balance -> order
  # -> user decoration. Everything commits or everything rolls back, so
  # "a failed purchase never spends points" is guaranteed structurally.
  class Purchases
    def self.purchase!(user:, item_id:)
      order = nil
      ShopItem.transaction do
        account = PointAccount.lock_for(user.id)

        item = ShopItem.find_by(id: item_id)
        raise ShopError.new(:item_not_found) if item.blank? || !item.listed?
        raise ShopError.new(:item_not_purchasable) if item.decoration_asset_id.blank?
        raise ShopError.new(:insufficient_balance) if account.balance < item.price

        if item.purchase_limit_per_user.present?
          fulfilled_count = ShopOrder.fulfilled.where(user_id: user.id, shop_item_id: item.id).count
          if fulfilled_count >= item.purchase_limit_per_user
            raise ShopError.new(:purchase_limit_reached)
          end
        end

        raise ShopError.new(:out_of_stock) unless ShopItem.claim_stock!(item.id)

        order =
          ShopOrder.create!(
            user_id: user.id,
            shop_item_id: item.id,
            price_paid: item.price,
            status: ShopOrder::FULFILLED,
          )

        if item.price > 0
          PointsLedger.apply!(
            user_id: user.id,
            amount: -item.price,
            entry_type: PointLedgerEntry::PURCHASE_SPEND,
            reference: order,
            description: item.name,
          )
        end

        UserDecoration.create!(
          user_id: user.id,
          decoration_asset_id: item.decoration_asset_id,
          source: UserDecoration::PURCHASE,
          source_id: order.id,
          equipped: false,
        )
      end
      order
    end
  end
end
