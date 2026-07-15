# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Equipping do
  fab!(:user)
  fab!(:other_user) { Fabricate(:user) }
  fab!(:username_asset) { Fabricate(:gamified_shop_decoration_asset) }
  fab!(:other_username_asset) { Fabricate(:gamified_shop_decoration_asset) }
  fab!(:frame_asset) { Fabricate(:gamified_shop_avatar_frame_asset) }

  before { SiteSetting.gamified_shop_enabled = true }

  def own_decoration(asset, **attrs)
    Fabricate(:gamified_shop_user_decoration, user: user, decoration_asset: asset, **attrs)
  end

  def expect_shop_error(code, &blk)
    expect(&blk).to raise_error(GamifiedShop::ShopError) do |error|
      expect(error.code).to eq(code)
    end
  end

  describe ".equip!" do
    it "equips the decoration" do
      decoration = own_decoration(username_asset)

      result = described_class.equip!(user: user, user_decoration_id: decoration.id)

      expect(result.id).to eq(decoration.id)
      expect(decoration.reload.equipped).to eq(true)
      expect(decoration.displayable?).to eq(true)
    end

    it "unequips the same-slot incumbent in the same call" do
      incumbent = own_decoration(username_asset, equipped: true)
      challenger = own_decoration(other_username_asset)

      described_class.equip!(user: user, user_decoration_id: challenger.id)

      expect(incumbent.reload.equipped).to eq(false)
      expect(challenger.reload.equipped).to eq(true)
    end

    it "lets decorations in different slots stay equipped together" do
      username_decoration = own_decoration(username_asset)
      frame_decoration = own_decoration(frame_asset)

      described_class.equip!(user: user, user_decoration_id: username_decoration.id)
      described_class.equip!(user: user, user_decoration_id: frame_decoration.id)

      expect(username_decoration.reload.equipped).to eq(true)
      expect(frame_decoration.reload.equipped).to eq(true)
    end

    it "refuses to equip an expired decoration" do
      decoration = own_decoration(username_asset, expires_at: 1.day.ago)

      expect_shop_error(:decoration_expired) do
        described_class.equip!(user: user, user_decoration_id: decoration.id)
      end
      expect(decoration.reload.equipped).to eq(false)
    end

    it "does not expose decorations belonging to other users" do
      foreign =
        Fabricate(
          :gamified_shop_user_decoration,
          user: other_user,
          decoration_asset: username_asset,
        )

      expect_shop_error(:decoration_not_found) do
        described_class.equip!(user: user, user_decoration_id: foreign.id)
      end
      expect(foreign.reload.equipped).to eq(false)
    end

    it "raises decoration_not_found for a nonexistent id" do
      expect_shop_error(:decoration_not_found) do
        described_class.equip!(user: user, user_decoration_id: -1)
      end
    end
  end

  describe ".unequip!" do
    it "unequips the decoration" do
      decoration = own_decoration(username_asset, equipped: true)

      result = described_class.unequip!(user: user, user_decoration_id: decoration.id)

      expect(result.id).to eq(decoration.id)
      expect(decoration.reload.equipped).to eq(false)
    end

    it "does not expose decorations belonging to other users" do
      foreign =
        Fabricate(
          :gamified_shop_user_decoration,
          user: other_user,
          decoration_asset: username_asset,
          equipped: true,
        )

      expect_shop_error(:decoration_not_found) do
        described_class.unequip!(user: user, user_decoration_id: foreign.id)
      end
      expect(foreign.reload.equipped).to eq(true)
    end
  end
end
