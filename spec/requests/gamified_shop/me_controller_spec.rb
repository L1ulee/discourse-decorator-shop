# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::MeController do
  fab!(:user)

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

  describe "GET /gamified-shop/me/balance.json" do
    it "returns 404 when the plugin is disabled" do
      SiteSetting.gamified_shop_enabled = false
      sign_in(user)

      get "/gamified-shop/me/balance.json"

      expect(response.status).to eq(404)
    end

    it "returns 403 when not logged in" do
      get "/gamified-shop/me/balance.json"

      expect(response.status).to eq(403)
    end

    it "returns the balance and currency name" do
      sign_in(user)
      grant_points(user, 17)

      get "/gamified-shop/me/balance.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include("balance" => 17, "currency_name" => "Sparks")
    end

    it "returns a zero balance for users without an account row" do
      sign_in(user)

      get "/gamified-shop/me/balance.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["balance"]).to eq(0)
    end
  end

  describe "GET /gamified-shop/me/decorations.json" do
    it "returns 404 when the plugin is disabled" do
      SiteSetting.gamified_shop_enabled = false
      sign_in(user)

      get "/gamified-shop/me/decorations.json"

      expect(response.status).to eq(404)
    end

    it "returns 403 when not logged in" do
      get "/gamified-shop/me/decorations.json"

      expect(response.status).to eq(403)
    end

    it "returns the user's decorations with balance and currency name" do
      sign_in(user)
      grant_points(user, 5)
      decoration = Fabricate(:gamified_shop_user_decoration, user: user, equipped: true)
      Fabricate(:gamified_shop_user_decoration) # someone else's

      get "/gamified-shop/me/decorations.json"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["balance"]).to eq(5)
      expect(body["currency_name"]).to eq("Sparks")
      expect(body["decorations"].length).to eq(1)

      serialized = body["decorations"].first
      expect(serialized["id"]).to eq(decoration.id)
      expect(serialized["user_id"]).to eq(user.id)
      expect(serialized["decoration_asset_id"]).to eq(decoration.decoration_asset_id)
      expect(serialized["source"]).to eq("admin_grant")
      expect(serialized["equipped"]).to eq(true)
      expect(serialized["expires_at"]).to be_nil
      expect(serialized["displayable"]).to eq(true)
      expect(serialized["decoration_asset"]["id"]).to eq(decoration.decoration_asset_id)
      expect(serialized["decoration_asset"]["slot"]).to eq("username_style")
    end

    it "marks expired decorations as not displayable" do
      sign_in(user)
      Fabricate(:gamified_shop_user_decoration, user: user, equipped: true, expires_at: 1.day.ago)

      get "/gamified-shop/me/decorations.json"

      expect(response.status).to eq(200)
      serialized = response.parsed_body["decorations"].first
      expect(serialized["equipped"]).to eq(true)
      expect(serialized["displayable"]).to eq(false)
    end
  end

  describe "POST /gamified-shop/me/decorations/:id/equip.json" do
    fab!(:decoration) { Fabricate(:gamified_shop_user_decoration, user: user) }

    it "equips the decoration and returns it" do
      sign_in(user)

      post "/gamified-shop/me/decorations/#{decoration.id}/equip.json"

      expect(response.status).to eq(200)
      serialized = response.parsed_body["decoration"]
      expect(serialized["id"]).to eq(decoration.id)
      expect(serialized["equipped"]).to eq(true)
      expect(serialized["displayable"]).to eq(true)
      expect(decoration.reload.equipped).to eq(true)
    end

    it "unequips the previous decoration in the same slot" do
      sign_in(user)
      other = Fabricate(:gamified_shop_user_decoration, user: user, equipped: true)

      post "/gamified-shop/me/decorations/#{decoration.id}/equip.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["decoration"]["equipped"]).to eq(true)
      expect(decoration.reload.equipped).to eq(true)
      expect(other.reload.equipped).to eq(false)

      get "/gamified-shop/me/decorations.json"

      equipped_by_id = response.parsed_body["decorations"].to_h { |d| [d["id"], d["equipped"]] }
      expect(equipped_by_id[decoration.id]).to eq(true)
      expect(equipped_by_id[other.id]).to eq(false)
    end

    it "keeps decorations in other slots equipped" do
      sign_in(user)
      frame =
        Fabricate(
          :gamified_shop_user_decoration,
          user: user,
          equipped: true,
          decoration_asset: Fabricate(:gamified_shop_avatar_frame_asset),
        )

      post "/gamified-shop/me/decorations/#{decoration.id}/equip.json"

      expect(response.status).to eq(200)
      expect(frame.reload.equipped).to eq(true)
    end

    it "returns 422 when equipping an expired decoration" do
      sign_in(user)
      decoration.update!(expires_at: 1.day.ago)

      post "/gamified-shop/me/decorations/#{decoration.id}/equip.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("gamified_shop.errors.decoration_expired"),
      )
      expect(decoration.reload.equipped).to eq(false)
    end

    it "returns 422 when equipping another user's decoration" do
      sign_in(user)
      foreign = Fabricate(:gamified_shop_user_decoration)

      post "/gamified-shop/me/decorations/#{foreign.id}/equip.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("gamified_shop.errors.decoration_not_found"),
      )
      expect(foreign.reload.equipped).to eq(false)
    end

    it "returns 403 when not logged in" do
      post "/gamified-shop/me/decorations/#{decoration.id}/equip.json"

      expect(response.status).to eq(403)
    end
  end

  describe "POST /gamified-shop/me/decorations/:id/unequip.json" do
    fab!(:decoration) { Fabricate(:gamified_shop_user_decoration, user: user, equipped: true) }

    it "unequips the decoration and returns it" do
      sign_in(user)

      post "/gamified-shop/me/decorations/#{decoration.id}/unequip.json"

      expect(response.status).to eq(200)
      serialized = response.parsed_body["decoration"]
      expect(serialized["id"]).to eq(decoration.id)
      expect(serialized["equipped"]).to eq(false)
      expect(serialized["displayable"]).to eq(false)
      expect(decoration.reload.equipped).to eq(false)
    end

    it "returns 403 when not logged in" do
      post "/gamified-shop/me/decorations/#{decoration.id}/unequip.json"

      expect(response.status).to eq(403)
    end
  end
end
