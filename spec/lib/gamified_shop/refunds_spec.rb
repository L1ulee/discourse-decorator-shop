# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Refunds do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:item) { Fabricate(:gamified_shop_item, price: 30, stock: 5) }

  before { SiteSetting.gamified_shop_enabled = true }

  def grant_points(target_user, amount)
    GamifiedShop::PointsLedger.apply!(
      user_id: target_user.id,
      amount: amount,
      entry_type: GamifiedShop::PointLedgerEntry::ADMIN_GRANT,
    )
  end

  def balance(target_user)
    GamifiedShop::PointAccount.balance_for(target_user.id)
  end

  def place_order(buyer, purchased_item = item)
    grant_points(buyer, 100)
    GamifiedShop::Purchases.purchase!(user: buyer, item_id: purchased_item.id)
  end

  def expect_shop_error(code, &blk)
    expect(&blk).to raise_error(GamifiedShop::ShopError) do |error|
      expect(error.code).to eq(code)
    end
  end

  describe ".refund!" do
    context "when checking permissions" do
      it "raises Discourse::InvalidAccess for moderators" do
        order = place_order(user)

        expect {
          described_class.refund!(order_id: order.id, refunded_by: moderator)
        }.to raise_error(Discourse::InvalidAccess)
        expect(order.reload.status).to eq(GamifiedShop::ShopOrder::FULFILLED)
      end

      it "raises Discourse::InvalidAccess for regular users" do
        order = place_order(user)

        expect { described_class.refund!(order_id: order.id, refunded_by: user) }.to raise_error(
          Discourse::InvalidAccess,
        )
        expect(order.reload.status).to eq(GamifiedShop::ShopOrder::FULFILLED)
      end
    end

    context "when the refund succeeds" do
      it "returns the points, ends the decoration, releases stock and flips the order" do
        order = place_order(user)
        decoration =
          GamifiedShop::UserDecoration.find_by(
            source: GamifiedShop::UserDecoration::PURCHASE,
            source_id: order.id,
          )
        GamifiedShop::Equipping.equip!(user: user, user_decoration_id: decoration.id)
        expect(balance(user)).to eq(70)
        expect(item.reload.stock).to eq(4)

        refunded = described_class.refund!(order_id: order.id, refunded_by: admin)

        expect(refunded.id).to eq(order.id)
        expect(refunded.status).to eq(GamifiedShop::ShopOrder::REFUNDED)
        expect(refunded.refunded_at).to be_within(5.seconds).of(Time.zone.now)

        expect(balance(user)).to eq(100)
        entry =
          GamifiedShop::PointLedgerEntry.find_by(
            user_id: user.id,
            entry_type: GamifiedShop::PointLedgerEntry::PURCHASE_REFUND,
          )
        expect(entry).to be_present
        expect(entry.amount).to eq(30)
        expect(entry.reference_type).to eq("GamifiedShop::ShopOrder")
        expect(entry.reference_id).to eq(order.id)
        expect(entry.created_by_id).to eq(admin.id)

        decoration.reload
        expect(decoration.equipped).to eq(false)
        expect(decoration.expires_at).to be_within(5.seconds).of(Time.zone.now)
        expect(decoration.expired?).to eq(true)
        expect(decoration.displayable?).to eq(false)

        expect(item.reload.stock).to eq(5)
      end

      it "logs the refund to the staff action log" do
        order = place_order(user)

        described_class.refund!(order_id: order.id, refunded_by: admin)

        expect(UserHistory.where(custom_type: "gamified_shop_refund_order").exists?).to eq(true)
      end

      it "leaves unlimited (nil) stock untouched" do
        unlimited_item = Fabricate(:gamified_shop_item, price: 30, stock: nil)
        order = place_order(user, unlimited_item)

        described_class.refund!(order_id: order.id, refunded_by: admin)

        expect(unlimited_item.reload.stock).to be_nil
      end

      it "keeps the ledger sum equal to the cached balance" do
        order = place_order(user)

        described_class.refund!(order_id: order.id, refunded_by: admin)

        expect(GamifiedShop::PointLedgerEntry.where(user_id: user.id).sum(:amount)).to eq(
          balance(user),
        )
      end
    end

    context "when the refund is invalid" do
      it "rejects a nonexistent order with order_not_found" do
        expect_shop_error(:order_not_found) do
          described_class.refund!(order_id: -1, refunded_by: admin)
        end
      end

      it "rejects a second refund with order_not_refundable" do
        order = place_order(user)
        described_class.refund!(order_id: order.id, refunded_by: admin)

        expect_shop_error(:order_not_refundable) do
          described_class.refund!(order_id: order.id, refunded_by: admin)
        end

        expect(balance(user)).to eq(100)
        expect(
          GamifiedShop::PointLedgerEntry.where(
            user_id: user.id,
            entry_type: GamifiedShop::PointLedgerEntry::PURCHASE_REFUND,
          ).count,
        ).to eq(1)
        expect(item.reload.stock).to eq(5)
      end
    end
  end
end
