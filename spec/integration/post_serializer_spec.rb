# frozen_string_literal: true

require "rails_helper"

# The post stream (PostStreamSerializerMixin) serializes each post with
# PostSerializer, so the plugin's :post gamified_shop attribute must survive
# there. An object-referencing include_condition silently dropped the field
# (issue #2/#6: in-post decorations never rendered because the <article> got
# no gds-un-/gds-af- classes).
RSpec.describe PostSerializer do
  fab!(:user)
  fab!(:post) { Fabricate(:post, user: user) }

  before { SiteSetting.gamified_shop_enabled = true }

  def serialized
    described_class.new(post, scope: Guardian.new(user), root: false).as_json
  end

  it "exposes the author's equipped decorations to the post stream" do
    asset = Fabricate(:gamified_shop_decoration_asset) # username_style slot
    Fabricate(:gamified_shop_user_decoration, user: user, decoration_asset: asset, equipped: true)

    expect(serialized[:gamified_shop]).to eq("username_style" => asset.id)
  end

  it "serializes an empty map when the author has nothing equipped" do
    expect(serialized[:gamified_shop]).to eq({})
  end

  it "omits the field entirely when the plugin is disabled" do
    SiteSetting.gamified_shop_enabled = false

    expect(serialized.key?(:gamified_shop)).to eq(false)
  end
end
