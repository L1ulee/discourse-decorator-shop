# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Grants do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:asset) { Fabricate(:gamified_shop_decoration_asset) }

  before { SiteSetting.gamified_shop_enabled = true }

  def balance(target_user)
    GamifiedShop::PointAccount.balance_for(target_user.id)
  end

  def expect_shop_error(code, &blk)
    expect(&blk).to raise_error(GamifiedShop::ShopError) do |error|
      expect(error.code).to eq(code)
    end
  end

  describe ".adjust_points!" do
    it "credits a positive amount as an admin_grant entry" do
      entry =
        described_class.adjust_points!(
          user: user,
          amount: 50,
          acting_user: admin,
          description: "event prize",
        )

      expect(entry.entry_type).to eq(GamifiedShop::PointLedgerEntry::ADMIN_GRANT)
      expect(entry.amount).to eq(50)
      expect(entry.balance_after).to eq(50)
      expect(entry.created_by_id).to eq(admin.id)
      expect(entry.description).to eq("event prize")
      expect(balance(user)).to eq(50)
    end

    it "debits a negative amount as an admin_deduct entry" do
      described_class.adjust_points!(user: user, amount: 50, acting_user: admin)

      entry = described_class.adjust_points!(user: user, amount: -20, acting_user: admin)

      expect(entry.entry_type).to eq(GamifiedShop::PointLedgerEntry::ADMIN_DEDUCT)
      expect(entry.amount).to eq(-20)
      expect(entry.balance_after).to eq(30)
      expect(balance(user)).to eq(30)
    end

    it "rejects a zero amount with invalid_amount" do
      expect_shop_error(:invalid_amount) do
        described_class.adjust_points!(user: user, amount: 0, acting_user: admin)
      end
      expect(GamifiedShop::PointLedgerEntry.where(user_id: user.id).count).to eq(0)
    end

    it "blocks moderators while gamified_shop_allow_moderator_grants is off" do
      SiteSetting.gamified_shop_allow_moderator_grants = false

      expect {
        described_class.adjust_points!(user: user, amount: 10, acting_user: moderator)
      }.to raise_error(Discourse::InvalidAccess)
      expect(balance(user)).to eq(0)
    end

    it "allows moderators when gamified_shop_allow_moderator_grants is on" do
      SiteSetting.gamified_shop_allow_moderator_grants = true

      entry = described_class.adjust_points!(user: user, amount: 10, acting_user: moderator)

      expect(entry.entry_type).to eq(GamifiedShop::PointLedgerEntry::ADMIN_GRANT)
      expect(entry.created_by_id).to eq(moderator.id)
      expect(balance(user)).to eq(10)
    end

    it "always blocks regular users" do
      SiteSetting.gamified_shop_allow_moderator_grants = true

      expect {
        described_class.adjust_points!(user: user, amount: 10, acting_user: user)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe ".grant_decoration!" do
    it "creates a user decoration with source admin_grant" do
      decoration =
        described_class.grant_decoration!(
          user: user,
          decoration_asset_id: asset.id,
          acting_user: admin,
        )

      expect(decoration).to be_persisted
      expect(decoration.user_id).to eq(user.id)
      expect(decoration.decoration_asset_id).to eq(asset.id)
      expect(decoration.source).to eq(GamifiedShop::UserDecoration::ADMIN_GRANT)
      expect(decoration.equipped).to eq(false)
    end

    it "rejects a nonexistent asset with asset_not_found" do
      expect_shop_error(:asset_not_found) do
        described_class.grant_decoration!(user: user, decoration_asset_id: -1, acting_user: admin)
      end
    end

    it "blocks moderators while gamified_shop_allow_moderator_grants is off" do
      SiteSetting.gamified_shop_allow_moderator_grants = false

      expect {
        described_class.grant_decoration!(
          user: user,
          decoration_asset_id: asset.id,
          acting_user: moderator,
        )
      }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe ".revoke_decoration!" do
    it "unequips the decoration and expires it immediately" do
      decoration =
        Fabricate(
          :gamified_shop_user_decoration,
          user: user,
          decoration_asset: asset,
          equipped: true,
        )

      described_class.revoke_decoration!(user_decoration_id: decoration.id, acting_user: admin)

      decoration.reload
      expect(decoration.equipped).to eq(false)
      expect(decoration.expires_at).to be_within(5.seconds).of(Time.zone.now)
      expect(decoration.displayable?).to eq(false)
    end

    it "rejects a nonexistent decoration with decoration_not_found" do
      expect_shop_error(:decoration_not_found) do
        described_class.revoke_decoration!(user_decoration_id: -1, acting_user: admin)
      end
    end
  end

  describe "staff action logging" do
    it "logs point grants, point deductions, decoration grants and revokes" do
      described_class.adjust_points!(user: user, amount: 5, acting_user: admin)
      described_class.adjust_points!(user: user, amount: -3, acting_user: admin)
      decoration =
        described_class.grant_decoration!(
          user: user,
          decoration_asset_id: asset.id,
          acting_user: admin,
        )
      described_class.revoke_decoration!(user_decoration_id: decoration.id, acting_user: admin)

      expect(
        UserHistory.where(acting_user_id: admin.id, custom_type: "gamified_shop_adjust_points").count,
      ).to eq(2)
      expect(
        UserHistory.where(
          acting_user_id: admin.id,
          custom_type: "gamified_shop_grant_decoration",
        ).exists?,
      ).to eq(true)
      expect(
        UserHistory.where(
          acting_user_id: admin.id,
          custom_type: "gamified_shop_revoke_decoration",
        ).exists?,
      ).to eq(true)
    end
  end
end
