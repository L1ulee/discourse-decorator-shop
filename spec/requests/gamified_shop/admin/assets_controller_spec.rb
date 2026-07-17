# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Admin::AssetsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  before { SiteSetting.gamified_shop_enabled = true }

  let(:valid_preset_params) do
    {
      name: "Solid Gold",
      slot: "username_style",
      style_preset: "username_solid",
      style_params: {
        color: "#ffd700",
      },
    }
  end

  context "when logged in as a normal user" do
    before { sign_in(user) }

    it "returns 404 for every endpoint" do
      get "/admin/plugins/gamified-shop/assets.json"
      expect(response.status).to eq(404)

      post "/admin/plugins/gamified-shop/assets.json", params: valid_preset_params
      expect(response.status).to eq(404)

      delete "/admin/plugins/gamified-shop/assets/1.json"
      expect(response.status).to eq(404)

      expect(GamifiedShop::DecorationAsset.count).to eq(0)
    end
  end

  context "when logged in as a moderator" do
    before { sign_in(moderator) }

    it "can list assets" do
      asset = Fabricate(:gamified_shop_decoration_asset)

      get "/admin/plugins/gamified-shop/assets.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["assets"].map { |a| a["id"] }).to eq([asset.id])
    end

    it "can create an asset from a preset" do
      expect {
        post "/admin/plugins/gamified-shop/assets.json", params: valid_preset_params
      }.to change { GamifiedShop::DecorationAsset.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["asset"]["style_preset"]).to eq("username_solid")
    end

    it "cannot create an asset with custom_css (admin-only)" do
      expect {
        post "/admin/plugins/gamified-shop/assets.json",
             params: valid_preset_params.merge(custom_css: "text-decoration: underline;")
      }.not_to change { GamifiedShop::DecorationAsset.count }

      expect(response.status).to eq(403)
    end
  end

  context "when logged in as an admin" do
    before { sign_in(admin) }

    describe "#index" do
      it "includes the admin-only attributes" do
        asset = Fabricate(:gamified_shop_decoration_asset, custom_css: "letter-spacing: 1px;")

        get "/admin/plugins/gamified-shop/assets.json"

        expect(response.status).to eq(200)
        serialized = response.parsed_body["assets"].first
        expect(serialized["id"]).to eq(asset.id)
        expect(serialized["custom_css"]).to eq("letter-spacing: 1px;")
        expect(serialized["style_params"]).to eq("color" => "#ff0000")
        expect(serialized["in_use"]).to eq(false)
      end
    end

    describe "#create" do
      it "creates a username style asset from a valid preset" do
        expect {
          post "/admin/plugins/gamified-shop/assets.json", params: valid_preset_params
        }.to change { GamifiedShop::DecorationAsset.count }.by(1)

        expect(response.status).to eq(200)
        asset = response.parsed_body["asset"]
        expect(asset["name"]).to eq("Solid Gold")
        expect(asset["slot"]).to eq("username_style")
        expect(asset["style_preset"]).to eq("username_solid")
        expect(asset["style_params"]).to eq("color" => "#ffd700")
      end

      it "creates an avatar frame asset from an upload" do
        upload = Fabricate(:upload, animated: false)

        post "/admin/plugins/gamified-shop/assets.json",
             params: {
               name: "Golden Frame",
               slot: "avatar_frame",
               upload_id: upload.id,
             }

        expect(response.status).to eq(200)
        asset = response.parsed_body["asset"]
        expect(asset["slot"]).to eq("avatar_frame")
        expect(asset["upload_id"]).to eq(upload.id)
        expect(asset["image_url"]).to eq(upload.url)
      end

      it "accepts custom_css from an admin" do
        post "/admin/plugins/gamified-shop/assets.json",
             params: valid_preset_params.merge(custom_css: "text-decoration: underline;")

        expect(response.status).to eq(200)
        expect(response.parsed_body["asset"]["custom_css"]).to eq("text-decoration: underline;")
      end

      it "rejects an invalid preset color with 422" do
        expect {
          post "/admin/plugins/gamified-shop/assets.json",
               params: valid_preset_params.merge(style_params: { color: "gold" })
        }.not_to change { GamifiedShop::DecorationAsset.count }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    describe "#update" do
      it "updates an asset's name" do
        asset = Fabricate(:gamified_shop_decoration_asset)

        # Mirrors the admin form, which resubmits the full style payload.
        put "/admin/plugins/gamified-shop/assets/#{asset.id}.json",
            params: {
              name: "Renamed",
              slot: "username_style",
              style_preset: "username_solid",
              style_params: {
                color: "#ffd700",
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["asset"]["name"]).to eq("Renamed")
        expect(asset.reload.name).to eq("Renamed")
      end

      it "switches a style asset to a different preset" do
        asset = Fabricate(:gamified_shop_decoration_asset)

        put "/admin/plugins/gamified-shop/assets/#{asset.id}.json",
            params: {
              name: asset.name,
              slot: "username_style",
              style_preset: "username_rainbow",
            }

        expect(response.status).to eq(200)
        expect(asset.reload.style_preset).to eq("username_rainbow")
      end

      it "returns 422 for an unknown asset" do
        put "/admin/plugins/gamified-shop/assets/0.json",
            params: {
              name: "X",
              slot: "avatar_frame",
            }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("gamified_shop.errors.asset_not_found"),
        )
      end
    end

    describe "#destroy" do
      fab!(:asset, :gamified_shop_decoration_asset)

      it "destroys an unused asset" do
        delete "/admin/plugins/gamified-shop/assets/#{asset.id}.json"

        expect(response.status).to eq(200)
        expect(GamifiedShop::DecorationAsset.exists?(asset.id)).to eq(false)
      end

      it "deletes the asset and unlinks its shop item, preserving orders" do
        item = Fabricate(:gamified_shop_item, decoration_asset: asset)
        order = Fabricate(:gamified_shop_order, shop_item: item)

        delete "/admin/plugins/gamified-shop/assets/#{asset.id}.json"

        expect(response.status).to eq(200)
        expect(GamifiedShop::DecorationAsset.exists?(asset.id)).to eq(false)

        item.reload
        expect(item.decoration_asset_id).to be_nil
        expect(item.listed).to eq(false)
        # Order history is preserved (the item row stays, just unlinked).
        expect(GamifiedShop::ShopOrder.exists?(order.id)).to eq(true)
      end

      it "deletes the asset and removes it from users who own it" do
        decoration = Fabricate(:gamified_shop_user_decoration, decoration_asset: asset)

        delete "/admin/plugins/gamified-shop/assets/#{asset.id}.json"

        expect(response.status).to eq(200)
        expect(GamifiedShop::DecorationAsset.exists?(asset.id)).to eq(false)
        expect(GamifiedShop::UserDecoration.exists?(decoration.id)).to eq(false)
      end

      it "returns 422 for an unknown asset" do
        delete "/admin/plugins/gamified-shop/assets/0.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("gamified_shop.errors.asset_not_found"),
        )
      end
    end
  end
end
