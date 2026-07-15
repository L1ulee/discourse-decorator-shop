# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Admin::ItemsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:asset, :gamified_shop_decoration_asset)

  before { SiteSetting.gamified_shop_enabled = true }

  context "when logged in as a normal user" do
    before { sign_in(user) }

    it "returns 404 for every endpoint" do
      get "/admin/plugins/gamified-shop/items.json"
      expect(response.status).to eq(404)

      post "/admin/plugins/gamified-shop/items.json",
           params: {
             name: "X",
             price: 1,
             decoration_asset_id: asset.id,
           }
      expect(response.status).to eq(404)

      put "/admin/plugins/gamified-shop/items/1.json", params: { price: 1 }
      expect(response.status).to eq(404)

      expect(GamifiedShop::ShopItem.count).to eq(0)
    end
  end

  context "when logged in as a moderator" do
    before { sign_in(moderator) }

    it "returns 404 for every endpoint (items are admin-only)" do
      get "/admin/plugins/gamified-shop/items.json"
      expect(response.status).to eq(404)

      post "/admin/plugins/gamified-shop/items.json",
           params: {
             name: "X",
             price: 1,
             decoration_asset_id: asset.id,
           }
      expect(response.status).to eq(404)

      put "/admin/plugins/gamified-shop/items/1.json", params: { price: 1 }
      expect(response.status).to eq(404)

      expect(GamifiedShop::ShopItem.count).to eq(0)
    end
  end

  context "when logged in as an admin" do
    before { sign_in(admin) }

    it "returns 404 when the plugin is disabled" do
      SiteSetting.gamified_shop_enabled = false

      get "/admin/plugins/gamified-shop/items.json"
      expect(response.status).to eq(404)
    end

    describe "#index" do
      fab!(:item_a) { Fabricate(:gamified_shop_item, decoration_asset: asset) }
      fab!(:item_b) { Fabricate(:gamified_shop_item, decoration_asset: asset, listed: false) }

      it "lists all items (including unlisted) ordered by id" do
        get "/admin/plugins/gamified-shop/items.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["items"].map { |i| i["id"] }).to eq([item_a.id, item_b.id])
      end
    end

    describe "#create" do
      it "creates a decoration item" do
        expect {
          post "/admin/plugins/gamified-shop/items.json",
               params: {
                 name: "Solid Red Username",
                 description: "Paint your username red",
                 price: 100,
                 stock: 5,
                 purchase_limit_per_user: 1,
                 listed: true,
                 decoration_asset_id: asset.id,
               }
        }.to change { GamifiedShop::ShopItem.count }.by(1)

        expect(response.status).to eq(200)
        item = response.parsed_body["item"]
        expect(item["name"]).to eq("Solid Red Username")
        expect(item["description"]).to eq("Paint your username red")
        expect(item["price"]).to eq(100)
        expect(item["stock"]).to eq(5)
        expect(item["purchase_limit_per_user"]).to eq(1)
        expect(item["listed"]).to eq(true)
        expect(item["item_type"]).to eq("decoration")
        expect(item["decoration_asset"]["id"]).to eq(asset.id)
      end

      it "rejects a negative price with 422" do
        expect {
          post "/admin/plugins/gamified-shop/items.json",
               params: {
                 name: "Bad Price",
                 price: -5,
                 decoration_asset_id: asset.id,
               }
        }.not_to change { GamifiedShop::ShopItem.count }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "rejects a decoration item without an asset with 422" do
        post "/admin/plugins/gamified-shop/items.json", params: { name: "No asset", price: 10 }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    describe "#update" do
      fab!(:item) { Fabricate(:gamified_shop_item, decoration_asset: asset, price: 100) }

      it "updates the item" do
        put "/admin/plugins/gamified-shop/items/#{item.id}.json",
            params: {
              price: 250,
              listed: false,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["item"]["price"]).to eq(250)

        item.reload
        expect(item.price).to eq(250)
        expect(item.listed).to eq(false)
      end

      it "returns 422 for a validation error" do
        put "/admin/plugins/gamified-shop/items/#{item.id}.json", params: { price: -1 }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
        expect(item.reload.price).to eq(100)
      end

      it "returns 422 for an unknown item" do
        put "/admin/plugins/gamified-shop/items/0.json", params: { price: 1 }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("gamified_shop.errors.item_not_found"),
        )
      end
    end
  end
end
