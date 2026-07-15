# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Purchases do
  fab!(:user)
  fab!(:item) { Fabricate(:gamified_shop_item, price: 30, stock: 5) }

  before { SiteSetting.gamified_shop_enabled = true }

  def grant_points(target_user, amount)
    GamifiedShop::PointsLedger.apply!(
      user_id: target_user.id,
      amount: amount,
      entry_type:
        (
          if amount.positive?
            GamifiedShop::PointLedgerEntry::ADMIN_GRANT
          else
            GamifiedShop::PointLedgerEntry::ADMIN_DEDUCT
          end
        ),
    )
  end

  def balance(target_user)
    GamifiedShop::PointAccount.balance_for(target_user.id)
  end

  def expect_shop_error(code, &blk)
    expect(&blk).to raise_error(GamifiedShop::ShopError) do |error|
      expect(error.code).to eq(code)
    end
  end

  describe ".purchase!" do
    context "with a sufficient balance" do
      before { grant_points(user, 100) }

      it "fulfills the order and applies every side effect" do
        order = described_class.purchase!(user: user, item_id: item.id)

        expect(order).to be_persisted
        expect(order.user_id).to eq(user.id)
        expect(order.shop_item_id).to eq(item.id)
        expect(order.price_paid).to eq(30)
        expect(order.status).to eq(GamifiedShop::ShopOrder::FULFILLED)

        expect(balance(user)).to eq(70)

        entry =
          GamifiedShop::PointLedgerEntry.find_by(
            user_id: user.id,
            entry_type: GamifiedShop::PointLedgerEntry::PURCHASE_SPEND,
          )
        expect(entry).to be_present
        expect(entry.amount).to eq(-30)
        expect(entry.balance_after).to eq(70)
        expect(entry.reference_type).to eq("GamifiedShop::ShopOrder")
        expect(entry.reference_id).to eq(order.id)

        decoration = GamifiedShop::UserDecoration.find_by(user_id: user.id)
        expect(decoration).to be_present
        expect(decoration.decoration_asset_id).to eq(item.decoration_asset_id)
        expect(decoration.source).to eq(GamifiedShop::UserDecoration::PURCHASE)
        expect(decoration.source_id).to eq(order.id)
        expect(decoration.equipped).to eq(false)

        expect(item.reload.stock).to eq(4)
      end

      it "rejects an unlisted item with item_not_found" do
        item.update!(listed: false)

        expect_shop_error(:item_not_found) do
          described_class.purchase!(user: user, item_id: item.id)
        end
        expect(balance(user)).to eq(100)
        expect(GamifiedShop::ShopOrder.count).to eq(0)
      end

      it "rejects a nonexistent item with item_not_found" do
        expect_shop_error(:item_not_found) do
          described_class.purchase!(user: user, item_id: -1)
        end
      end

      it "rejects a sold-out item with out_of_stock" do
        item.update!(stock: 0)

        expect_shop_error(:out_of_stock) do
          described_class.purchase!(user: user, item_id: item.id)
        end
        expect(balance(user)).to eq(100)
        expect(GamifiedShop::ShopOrder.count).to eq(0)
        expect(item.reload.stock).to eq(0)
      end

      it "enforces the per-user purchase limit" do
        item.update!(purchase_limit_per_user: 1)

        described_class.purchase!(user: user, item_id: item.id)
        expect_shop_error(:purchase_limit_reached) do
          described_class.purchase!(user: user, item_id: item.id)
        end

        expect(GamifiedShop::ShopOrder.where(user_id: user.id).count).to eq(1)
        expect(balance(user)).to eq(70)
        expect(item.reload.stock).to eq(4)
      end

      it "never blocks on unlimited (nil) stock" do
        item.update!(stock: nil)

        described_class.purchase!(user: user, item_id: item.id)
        described_class.purchase!(user: user, item_id: item.id)

        expect(GamifiedShop::ShopOrder.fulfilled.where(user_id: user.id).count).to eq(2)
        expect(item.reload.stock).to be_nil
      end
    end

    context "with an insufficient balance" do
      it "rejects the purchase with insufficient_balance" do
        grant_points(user, 10)

        expect_shop_error(:insufficient_balance) do
          described_class.purchase!(user: user, item_id: item.id)
        end
        expect(balance(user)).to eq(10)
        expect(GamifiedShop::ShopOrder.count).to eq(0)
        expect(item.reload.stock).to eq(5)
      end

      it "blocks a negative-balance user even for a free item (balance < price guard)" do
        grant_points(user, -5)
        free_item = Fabricate(:gamified_shop_item, price: 0)

        expect_shop_error(:insufficient_balance) do
          described_class.purchase!(user: user, item_id: free_item.id)
        end
        expect(balance(user)).to eq(-5)
        expect(GamifiedShop::ShopOrder.count).to eq(0)
      end
    end

    context "with a free item" do
      it "succeeds without writing a ledger entry" do
        free_item = Fabricate(:gamified_shop_item, price: 0)

        order = described_class.purchase!(user: user, item_id: free_item.id)

        expect(order.status).to eq(GamifiedShop::ShopOrder::FULFILLED)
        expect(order.price_paid).to eq(0)
        expect(GamifiedShop::PointLedgerEntry.where(user_id: user.id).count).to eq(0)
        expect(balance(user)).to eq(0)
        expect(
          GamifiedShop::UserDecoration.where(user_id: user.id, source_id: order.id).count,
        ).to eq(1)
      end
    end

    context "when a step inside the transaction fails" do
      it "rolls back the ledger entry, order and stock claim" do
        grant_points(user, 100)
        allow(GamifiedShop::UserDecoration).to receive(:create!).and_raise(
          StandardError,
          "forced decoration failure",
        )

        expect { described_class.purchase!(user: user, item_id: item.id) }.to raise_error(
          StandardError,
          "forced decoration failure",
        )

        expect(balance(user)).to eq(100)
        expect(GamifiedShop::ShopOrder.count).to eq(0)
        expect(
          GamifiedShop::PointLedgerEntry.where(
            entry_type: GamifiedShop::PointLedgerEntry::PURCHASE_SPEND,
          ).count,
        ).to eq(0)
        expect(item.reload.stock).to eq(5)
      end
    end
  end
end
