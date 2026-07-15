# frozen_string_literal: true

module GamifiedShop
  # Admin-only whole-order refund (PRD 6.8): points back, the granted
  # decoration ends immediately, unit returns to stock, order flips to
  # refunded - one transaction.
  class Refunds
    def self.refund!(order_id:, refunded_by:)
      raise Discourse::InvalidAccess.new unless refunded_by&.admin?

      order = nil
      ShopOrder.transaction do
        order = ShopOrder.lock.find_by(id: order_id)
        raise ShopError.new(:order_not_found) if order.blank?
        raise ShopError.new(:order_not_refundable) if order.status != ShopOrder::FULFILLED

        if order.price_paid > 0
          PointsLedger.apply!(
            user_id: order.user_id,
            amount: order.price_paid,
            entry_type: PointLedgerEntry::PURCHASE_REFUND,
            reference: order,
            created_by_id: refunded_by.id,
          )
        end

        UserDecoration
          .where(source: UserDecoration::PURCHASE, source_id: order.id)
          .find_each do |decoration|
            decoration.update!(
              equipped: false,
              expires_at: decoration.expired? ? decoration.expires_at : Time.zone.now,
            )
          end

        ShopItem.release_stock!(order.shop_item_id)
        order.update!(status: ShopOrder::REFUNDED, refunded_at: Time.zone.now)
      end

      StaffActionLogger.new(refunded_by).log_custom(
        "gamified_shop_refund_order",
        order_id: order.id,
        target_user_id: order.user_id,
        amount: order.price_paid,
      )
      order
    end
  end
end
