# frozen_string_literal: true

require "rails_helper"

# End-to-end wiring: real PostCreator / PostActionCreator / PostDestroyer
# flows must move the ledger through the plugin.rb event subscriptions
# (PRD 16.1) - not by calling GamifiedShop::Earnings directly.
describe "GamifiedShop event wiring" do
  fab!(:user)
  fab!(:other_user, :user)
  # This test exercises the earning events, not permissions. A fabricated user
  # cannot clear the topic-creation guardian in the test DB (Discourse::
  # InvalidAccess "can_create? failed"), so PostCreator is called with
  # skip_guardian: true; the explicit category keeps the topic save valid.
  fab!(:category)

  before do
    SiteSetting.gamified_shop_enabled = true
    SiteSetting.gamified_shop_topic_created_points = 5
    SiteSetting.gamified_shop_reply_created_points = 2
    SiteSetting.gamified_shop_like_received_points = 1
    SiteSetting.gamified_shop_daily_earn_cap = 0
  end

  def balance_of(u)
    GamifiedShop::PointAccount.balance_for(u.id)
  end

  it "awards and claws back through the real Discourse events" do
    op =
      PostCreator.create!(
        user,
        title: "A perfectly valid shop wiring topic",
        raw: "This is a long enough body for the topic under test.",
        category: category.id,
        skip_guardian: true,
      )
    expect(balance_of(user)).to eq(5)

    reply =
      PostCreator.create!(
        other_user,
        topic_id: op.topic_id,
        raw: "This is a long enough reply body for the test.",
        skip_guardian: true,
      )
    expect(balance_of(other_user)).to eq(2)

    PostActionCreator.like(user, reply)
    expect(balance_of(other_user)).to eq(3)

    PostDestroyer.new(Discourse.system_user, reply.reload).destroy
    expect(balance_of(other_user)).to eq(0)

    PostDestroyer.new(Discourse.system_user, reply.reload).recover
    expect(balance_of(other_user)).to eq(3)
  end

  it "claws back the whole topic's rewards when the topic is deleted" do
    op =
      PostCreator.create!(
        user,
        title: "Another perfectly valid shop wiring topic",
        raw: "This is a long enough body for the second topic.",
        category: category.id,
        skip_guardian: true,
      )
    PostCreator.create!(
      other_user,
      topic_id: op.topic_id,
      raw: "This is a long enough reply body for the cascade test.",
      skip_guardian: true,
    )
    expect(balance_of(user)).to eq(5)
    expect(balance_of(other_user)).to eq(2)

    PostDestroyer.new(Discourse.system_user, op.reload).destroy

    expect(balance_of(user)).to eq(0)
    expect(balance_of(other_user)).to eq(0)
  end
end
