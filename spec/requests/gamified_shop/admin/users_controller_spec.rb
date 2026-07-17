# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Admin::UsersController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:target, :user)
  fab!(:asset, :gamified_shop_decoration_asset)

  before { SiteSetting.gamified_shop_enabled = true }

  let(:base_path) { "/admin/plugins/gamified-shop/users/#{target.id}" }

  context "when logged in as a normal user" do
    before { sign_in(user) }

    it "returns 404 for every endpoint" do
      get "#{base_path}.json"
      expect(response.status).to eq(404)

      post "#{base_path}/points.json", params: { amount: 10 }
      expect(response.status).to eq(404)

      post "#{base_path}/decorations.json", params: { decoration_asset_id: asset.id }
      expect(response.status).to eq(404)

      delete "#{base_path}/decorations/1.json"
      expect(response.status).to eq(404)

      expect(GamifiedShop::PointAccount.balance_for(target.id)).to eq(0)
      expect(GamifiedShop::UserDecoration.count).to eq(0)
    end
  end

  context "when logged in as a moderator" do
    before { sign_in(moderator) }

    it "can view a user's shop profile regardless of the grant setting" do
      SiteSetting.gamified_shop_allow_moderator_grants = false

      get "#{base_path}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["user"]["id"]).to eq(target.id)
    end

    context "when gamified_shop_allow_moderator_grants is disabled" do
      before { SiteSetting.gamified_shop_allow_moderator_grants = false }

      it "cannot adjust points" do
        post "#{base_path}/points.json", params: { amount: 10 }

        expect(response.status).to eq(403)
        expect(GamifiedShop::PointAccount.balance_for(target.id)).to eq(0)
      end

      it "cannot grant a decoration" do
        expect {
          post "#{base_path}/decorations.json", params: { decoration_asset_id: asset.id }
        }.not_to change { GamifiedShop::UserDecoration.count }

        expect(response.status).to eq(403)
      end

      it "cannot revoke a decoration" do
        decoration =
          Fabricate(
            :gamified_shop_user_decoration,
            user: target,
            decoration_asset: asset,
            equipped: true,
          )

        delete "#{base_path}/decorations/#{decoration.id}.json"

        expect(response.status).to eq(403)
        expect(decoration.reload.equipped).to eq(true)
      end
    end

    context "when gamified_shop_allow_moderator_grants is enabled" do
      before { SiteSetting.gamified_shop_allow_moderator_grants = true }

      it "can adjust points" do
        post "#{base_path}/points.json", params: { amount: 10, description: "mod grant" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["balance"]).to eq(10)
        expect(GamifiedShop::PointAccount.balance_for(target.id)).to eq(10)
      end

      it "can grant a decoration" do
        expect {
          post "#{base_path}/decorations.json", params: { decoration_asset_id: asset.id }
        }.to change { GamifiedShop::UserDecoration.count }.by(1)

        expect(response.status).to eq(200)
        expect(response.parsed_body["decoration"]["source"]).to eq("admin_grant")
      end

      it "still cannot deduct points (deduction is admin-only)" do
        GamifiedShop::PointsLedger.apply!(
          user_id: target.id,
          amount: 20,
          entry_type: "admin_grant",
          created_by_id: admin.id,
        )

        post "#{base_path}/points.json", params: { amount: -5 }

        expect(response.status).to eq(403)
        expect(GamifiedShop::PointAccount.balance_for(target.id)).to eq(20)
      end

      it "still cannot revoke a decoration (revoke is admin-only)" do
        decoration =
          Fabricate(
            :gamified_shop_user_decoration,
            user: target,
            decoration_asset: asset,
            equipped: true,
          )

        delete "#{base_path}/decorations/#{decoration.id}.json"

        expect(response.status).to eq(403)
        decoration.reload
        expect(decoration.equipped).to eq(true)
        expect(decoration.expired?).to eq(false)
      end
    end
  end

  context "when logged in as an admin" do
    before { sign_in(admin) }

    describe "#show" do
      it "returns the user's profile, balance, decorations and recent ledger" do
        GamifiedShop::PointsLedger.apply!(
          user_id: target.id,
          amount: 25,
          entry_type: "admin_grant",
          created_by_id: admin.id,
        )
        decoration =
          Fabricate(:gamified_shop_user_decoration, user: target, decoration_asset: asset)

        get "#{base_path}.json"

        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body["user"]["id"]).to eq(target.id)
        expect(body["balance"]).to eq(25)
        expect(body["decorations"].map { |d| d["id"] }).to eq([decoration.id])
        expect(body["ledger"].size).to eq(1)
        expect(body["ledger"].first["entry_type"]).to eq("admin_grant")
        expect(body["ledger"].first["balance_after"]).to eq(25)
      end

      it "returns 404 for an unknown user" do
        get "/admin/plugins/gamified-shop/users/0.json"

        expect(response.status).to eq(404)
      end
    end

    describe "#adjust_points" do
      it "credits points and returns the ledger entry" do
        post "#{base_path}/points.json", params: { amount: 50, description: "well done" }

        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body["balance"]).to eq(50)
        expect(body["entry"]["amount"]).to eq(50)
        expect(body["entry"]["entry_type"]).to eq("admin_grant")
        expect(body["entry"]["description"]).to eq("well done")
        expect(body["entry"]["created_by_id"]).to eq(admin.id)
        expect(GamifiedShop::PointAccount.balance_for(target.id)).to eq(50)
      end

      it "deducts points with a negative amount" do
        GamifiedShop::PointsLedger.apply!(
          user_id: target.id,
          amount: 50,
          entry_type: "admin_grant",
          created_by_id: admin.id,
        )

        post "#{base_path}/points.json", params: { amount: -20 }

        expect(response.status).to eq(200)
        expect(response.parsed_body["balance"]).to eq(30)
        expect(response.parsed_body["entry"]["entry_type"]).to eq("admin_deduct")
        expect(GamifiedShop::PointAccount.balance_for(target.id)).to eq(30)
      end

      it "rejects a zero amount with 422" do
        post "#{base_path}/points.json", params: { amount: 0 }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("gamified_shop.errors.invalid_amount"),
        )
      end
    end

    describe "#grant_decoration" do
      it "grants an unequipped decoration" do
        expect {
          post "#{base_path}/decorations.json", params: { decoration_asset_id: asset.id }
        }.to change { GamifiedShop::UserDecoration.count }.by(1)

        expect(response.status).to eq(200)
        decoration = response.parsed_body["decoration"]
        expect(decoration["user_id"]).to eq(target.id)
        expect(decoration["decoration_asset_id"]).to eq(asset.id)
        expect(decoration["source"]).to eq("admin_grant")
        expect(decoration["equipped"]).to eq(false)
        expect(decoration["expires_at"]).to be_nil
      end

      it "grants with a duration preset (issue #5)" do
        post "#{base_path}/decorations.json",
             params: {
               decoration_asset_id: asset.id,
               duration_days: 30,
             }

        expect(response.status).to eq(200)
        expect(GamifiedShop::UserDecoration.last.expires_at).to be_within(1.minute).of(
          30.days.from_now,
        )
      end

      it "grants with an absolute expiry date (issue #5)" do
        post "#{base_path}/decorations.json",
             params: {
               decoration_asset_id: asset.id,
               expires_at: 10.days.from_now.to_date.to_s,
             }

        expect(response.status).to eq(200)
        expect(GamifiedShop::UserDecoration.last.expires_at).to be_present
      end

      it "returns 422 for an expiry in the past (issue #5)" do
        post "#{base_path}/decorations.json",
             params: {
               decoration_asset_id: asset.id,
               expires_at: 2.days.ago.to_date.to_s,
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("gamified_shop.errors.invalid_expiry"),
        )
      end

      it "returns 422 for an unknown asset" do
        post "#{base_path}/decorations.json", params: { decoration_asset_id: 0 }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("gamified_shop.errors.asset_not_found"),
        )
      end
    end

    describe "#revoke_decoration" do
      it "removes the decoration from the user" do
        decoration =
          Fabricate(
            :gamified_shop_user_decoration,
            user: target,
            decoration_asset: asset,
            equipped: true,
          )

        delete "#{base_path}/decorations/#{decoration.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["removed"]).to eq(true)
        expect(response.parsed_body["id"]).to eq(decoration.id)
        expect(GamifiedShop::UserDecoration.exists?(decoration.id)).to eq(false)
      end

      it "returns 422 for an unknown decoration" do
        delete "#{base_path}/decorations/0.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("gamified_shop.errors.decoration_not_found"),
        )
      end
    end
  end
end
