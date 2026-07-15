# frozen_string_literal: true

require "rails_helper"

# End-to-end wiring: real PostCreator / PostActionCreator / PostDestroyer
# flows must move the ledger through the plugin.rb event subscriptions
# (PRD 16.1) - not by calling GamifiedShop::Earnings directly.
describe "GamifiedShop event wiring" do
  fab!(:user)
  fab!(:other_user, :user)
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

  # This spec verifies event wiring, not permissions, and a fabricated user
  # cannot clear the creation guardian in CI's Discourse (Discourse::
  # InvalidAccess "can_create? failed"). skip_validations bypasses the topic
  # guardian (TopicCreator#setup_topic_params) and skip_guardian bypasses the
  # reply guardian (PostCreator#valid?); both still fire the create events.
  def create_topic!(as:, title:)
    PostCreator.create!(
      as,
      title: title,
      raw: "This is a long enough body for the topic under test.",
      category: category.id,
      skip_validations: true,
      skip_guardian: true,
    )
  end

  def create_reply!(as:, topic_id:)
    PostCreator.create!(
      as,
      topic_id: topic_id,
      raw: "This is a long enough reply body for the test.",
      skip_validations: true,
      skip_guardian: true,
    )
  end

  it "awards and claws back through the real Discourse events" do
    op = create_topic!(as: user, title: "A perfectly valid shop wiring topic")
    expect(balance_of(user)).to eq(5)

    reply = create_reply!(as: other_user, topic_id: op.topic_id)
    expect(balance_of(other_user)).to eq(2)

    PostActionCreator.like(user, reply)
    expect(balance_of(other_user)).to eq(3)

    PostDestroyer.new(Discourse.system_user, reply.reload).destroy
    expect(balance_of(other_user)).to eq(0)

    PostDestroyer.new(Discourse.system_user, reply.reload).recover
    expect(balance_of(other_user)).to eq(3)
  end

  it "claws back the whole topic's rewards when the topic is deleted" do
    op = create_topic!(as: user, title: "Another perfectly valid shop wiring topic")
    create_reply!(as: other_user, topic_id: op.topic_id)
    expect(balance_of(user)).to eq(5)
    expect(balance_of(other_user)).to eq(2)

    PostDestroyer.new(Discourse.system_user, op.reload).destroy

    expect(balance_of(user)).to eq(0)
    expect(balance_of(other_user)).to eq(0)
  end
end
