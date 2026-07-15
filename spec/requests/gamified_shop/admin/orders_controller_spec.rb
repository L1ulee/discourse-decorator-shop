# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Admin::OrdersController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:buyer, :user)
  fab!(:asset, :gamified_shop_decoration_asset)
  fab!(:item) { Fabricate(:gamified_shop_item, decoration_asset: asset, price: 10, stock: 2) }

  before { SiteSetting.gamified_shop_enabled = true }

  context "when logged in as a normal user" do
    before { sign_in(user) }

    it "returns 404 for every endpoint" do
      get "/admin/plugins/gamified-shop/orders.json"
      expect(response.status).to eq(404)

      post "/admin/plugins/gamified-shop/orders/1/refund.json"
      expect(response.status).to eq(404)
    end
  end

  context "when logged in as a moderator" do
    before { sign_in(moderator) }

    it "returns 404 for every endpoint (orders are admin-only)" do
      order = Fabricate(:gamified_shop_order, user: buyer, shop_item: item, price_paid: 10)

      get "/admin/plugins/gamified-shop/orders.json"
      expect(response.status).to eq(404)

      post "/admin/plugins/gamified-shop/orders/#{order.id}/refund.json"
      expect(response.status).to eq(404)
      expect(order.reload.status).to eq("fulfilled")
    end
  end

  context "when logged in as an admin" do
    before { sign_in(admin) }

    describe "#index" do
      fab!(:fulfilled_order) do
        Fabricate(:gamified_shop_order, user: buyer, shop_item: item, price_paid: 10)
      end
      fab!(:refunded_order) do
        Fabricate(
          :gamified_shop_order,
          user: buyer,
          shop_item: item,
          price_paid: 10,
          status: "refunded",
          refunded_at: 1.day.ago,
        )
      end
      fab!(:other_order, :gamified_shop_order)

      it "lists orders newest first" do
        get "/admin/plugins/gamified-shop/orders.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["orders"].map { |o| o["id"] }).to eq(
          [other_order.id, refunded_order.id, fulfilled_order.id],
        )
      end

      it "filters by status" do
        get "/admin/plugins/gamified-shop/orders.json", params: { status: "refunded" }

        expect(response.status).to eq(200)
        orders = response.parsed_body["orders"]
        expect(orders.map { |o| o["id"] }).to eq([refunded_order.id])
        expect(orders.first["status"]).to eq("refunded")
        expect(orders.first["refunded_at"]).to be_present
      end

      it "filters by username" do
        get "/admin/plugins/gamified-shop/orders.json", params: { username: buyer.username }

        expect(response.status).to eq(200)
        expect(response.parsed_body["orders"].map { |o| o["id"] }).to eq(
          [refunded_order.id, fulfilled_order.id],
        )
      end

      it "filters by item" do
        get "/admin/plugins/gamified-shop/orders.json",
            params: {
              item_id: other_order.shop_item_id,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["orders"].map { |o| o["id"] }).to eq([other_order.id])
      end

      it "returns no orders for an unknown username" do
        get "/admin/plugins/gamified-shop/orders.json", params: { username: "no-such-user" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["orders"]).to eq([])
      end
    end

    describe "#refund" do
      fab!(:order) { Fabricate(:gamified_shop_order, user: buyer, shop_item: item, price_paid: 10) }
      fab!(:decoration) do
        Fabricate(
          :gamified_shop_user_decoration,
          user: buyer,
          decoration_asset: asset,
          source: "purchase",
          source_id: order.id,
          equipped: true,
        )
      end

      it "refunds points, ends the decoration and releases stock" do
        post "/admin/plugins/gamified-shop/orders/#{order.id}/refund.json"

        expect(response.status).to eq(200)
        body = response.parsed_body["order"]
        expect(body["id"]).to eq(order.id)
        expect(body["status"]).to eq("refunded")
        expect(body["refunded_at"]).to be_present

        expect(order.reload.status).to eq("refunded")
        expect(GamifiedShop::PointAccount.balance_for(buyer.id)).to eq(10)
        expect(item.reload.stock).to eq(3)

        decoration.reload
        expect(decoration.equipped).to eq(false)
        expect(decoration.expired?).to eq(true)

        entry = GamifiedShop::PointLedgerEntry.where(user_id: buyer.id).order(:id).last
        expect(entry.entry_type).to eq("purchase_refund")
        expect(entry.reference_type).to eq("GamifiedShop::ShopOrder")
        expect(entry.reference_id).to eq(order.id)
      end

      it "refunds only once" do
        post "/admin/plugins/gamified-shop/orders/#{order.id}/refund.json"
        expect(response.status).to eq(200)

        post "/admin/plugins/gamified-shop/orders/#{order.id}/refund.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("gamified_shop.errors.order_not_refundable"),
        )
        expect(GamifiedShop::PointAccount.balance_for(buyer.id)).to eq(10)
        expect(item.reload.stock).to eq(3)
      end

      it "returns 422 for an unknown order" do
        post "/admin/plugins/gamified-shop/orders/0/refund.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("gamified_shop.errors.order_not_found"),
        )
      end
    end
  end
end
