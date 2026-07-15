# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::PurchasesController do
  fab!(:user)
  fab!(:item) { Fabricate(:gamified_shop_item, price: 10) }

  before { SiteSetting.gamified_shop_enabled = true }

  def grant_points(user, amount)
    GamifiedShop::PointsLedger.apply!(
      user_id: user.id,
      amount: amount,
      entry_type: GamifiedShop::PointLedgerEntry::ADMIN_GRANT,
      description: "spec grant",
    )
  end

  describe "POST /gamified-shop/purchase.json" do
    it "returns 404 when the plugin is disabled" do
      SiteSetting.gamified_shop_enabled = false
      sign_in(user)

      post "/gamified-shop/purchase.json", params: { item_id: item.id }

      expect(response.status).to eq(404)
    end

    it "returns 403 when not logged in" do
      post "/gamified-shop/purchase.json", params: { item_id: item.id }

      expect(response.status).to eq(403)
    end

    it "returns the order and the new balance on success" do
      sign_in(user)
      grant_points(user, 100)

      expect { post "/gamified-shop/purchase.json", params: { item_id: item.id } }.to change {
        GamifiedShop::UserDecoration.where(user_id: user.id).count
      }.by(1)

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["balance"]).to eq(90)

      order = body["order"]
      expect(order["id"]).to be_present
      expect(order["user_id"]).to eq(user.id)
      expect(order["username"]).to eq(user.username)
      expect(order["shop_item_id"]).to eq(item.id)
      expect(order["item_name"]).to eq(item.name)
      expect(order["price_paid"]).to eq(10)
      expect(order["status"]).to eq(GamifiedShop::ShopOrder::FULFILLED)

      decoration = GamifiedShop::UserDecoration.find_by(user_id: user.id)
      expect(decoration.decoration_asset_id).to eq(item.decoration_asset_id)
      expect(decoration.equipped).to eq(false)
    end

    it "returns 422 with an error message when the balance is insufficient" do
      sign_in(user)
      grant_points(user, 5)

      expect { post "/gamified-shop/purchase.json", params: { item_id: item.id } }.not_to change {
        GamifiedShop::ShopOrder.count
      }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("gamified_shop.errors.insufficient_balance"),
      )
      expect(GamifiedShop::PointAccount.balance_for(user.id)).to eq(5)
    end

    it "returns 422 when buying past the per-user purchase limit" do
      item.update!(purchase_limit_per_user: 1)
      sign_in(user)
      grant_points(user, 100)

      post "/gamified-shop/purchase.json", params: { item_id: item.id }
      expect(response.status).to eq(200)

      expect { post "/gamified-shop/purchase.json", params: { item_id: item.id } }.not_to change {
        GamifiedShop::ShopOrder.count
      }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("gamified_shop.errors.purchase_limit_reached"),
      )
      expect(GamifiedShop::PointAccount.balance_for(user.id)).to eq(90)
    end

    it "returns 422 for an unlisted item" do
      item.update!(listed: false)
      sign_in(user)
      grant_points(user, 100)

      post "/gamified-shop/purchase.json", params: { item_id: item.id }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("gamified_shop.errors.item_not_found"),
      )
    end
  end
end
