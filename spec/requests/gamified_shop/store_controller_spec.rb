# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::StoreController do
  fab!(:user)
  fab!(:listed_item) { Fabricate(:gamified_shop_item, price: 25) }
  fab!(:unlisted_item) { Fabricate(:gamified_shop_item, listed: false) }

  before do
    SiteSetting.gamified_shop_enabled = true
    SiteSetting.gamified_shop_currency_name = "Sparks"
  end

  def grant_points(user, amount)
    GamifiedShop::PointsLedger.apply!(
      user_id: user.id,
      amount: amount,
      entry_type: GamifiedShop::PointLedgerEntry::ADMIN_GRANT,
      description: "spec grant",
    )
  end

  describe "GET /gamified-shop/store.json" do
    it "returns 404 when the plugin is disabled" do
      SiteSetting.gamified_shop_enabled = false
      sign_in(user)

      get "/gamified-shop/store.json"

      expect(response.status).to eq(404)
    end

    it "returns 403 when not logged in" do
      get "/gamified-shop/store.json"

      expect(response.status).to eq(403)
    end

    it "returns only listed items" do
      sign_in(user)

      get "/gamified-shop/store.json"

      expect(response.status).to eq(200)
      ids = response.parsed_body["items"].map { |item| item["id"] }
      expect(ids).to contain_exactly(listed_item.id)
    end

    it "serializes items with their decoration asset" do
      sign_in(user)

      get "/gamified-shop/store.json"

      expect(response.status).to eq(200)
      item = response.parsed_body["items"].first
      expect(item["name"]).to eq(listed_item.name)
      expect(item["item_type"]).to eq("decoration")
      expect(item["price"]).to eq(25)
      expect(item["listed"]).to eq(true)
      expect(item["decoration_asset"]["id"]).to eq(listed_item.decoration_asset_id)
      expect(item["decoration_asset"]["slot"]).to eq("username_style")
    end

    it "includes balance and currency_name" do
      sign_in(user)
      grant_points(user, 42)

      get "/gamified-shop/store.json"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["balance"]).to eq(42)
      expect(body["currency_name"]).to eq("Sparks")
    end

    it "includes the current user's fulfilled purchase counts per item" do
      sign_in(user)
      Fabricate(:gamified_shop_order, user: user, shop_item: listed_item)
      Fabricate(:gamified_shop_order, user: user, shop_item: listed_item)
      Fabricate(
        :gamified_shop_order,
        user: user,
        shop_item: listed_item,
        status: GamifiedShop::ShopOrder::REFUNDED,
      )
      Fabricate(:gamified_shop_order, shop_item: listed_item) # someone else's

      get "/gamified-shop/store.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["purchased_counts"]).to eq(listed_item.id.to_s => 2)
    end

    it "includes owned_asset_ids, excluding expired decorations" do
      sign_in(user)
      owned = Fabricate(:gamified_shop_user_decoration, user: user)
      Fabricate(:gamified_shop_user_decoration, user: user, expires_at: 1.day.ago)
      Fabricate(:gamified_shop_user_decoration) # someone else's

      get "/gamified-shop/store.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["owned_asset_ids"]).to contain_exactly(
        owned.decoration_asset_id,
      )
    end
  end
end
