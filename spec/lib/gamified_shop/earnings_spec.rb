# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::Earnings do
  fab!(:user)
  fab!(:liker) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: user) }
  fab!(:reply) { Fabricate(:post, topic: topic, user: user) }

  before do
    SiteSetting.gamified_shop_enabled = true
    SiteSetting.gamified_shop_topic_created_points = 5
    SiteSetting.gamified_shop_reply_created_points = 2
    SiteSetting.gamified_shop_like_received_points = 1
    SiteSetting.gamified_shop_daily_earn_cap = 0
  end

  def balance(u = user)
    GamifiedShop::PointAccount.balance_for(u.id)
  end

  def entries(u = user)
    GamifiedShop::PointLedgerEntry.where(user_id: u.id).order(:id)
  end

  def rewards(u = user)
    entries(u).where(entry_type: GamifiedShop::PointLedgerEntry::EVENT_REWARD)
  end

  def reversals(u = user)
    entries(u).where(entry_type: GamifiedShop::PointLedgerEntry::EVENT_REVERSAL)
  end

  # Creates the like PostAction row directly (not via PostActionCreator) so the
  # plugin's :like_created event listener does not award the points before the
  # example calls the Earnings method under test.
  def like!(post, from:)
    PostAction.create!(user: from, post: post, post_action_type_id: PostActionType.types[:like])
  end

  describe ".topic_created" do
    it "awards the configured points and references the topic" do
      described_class.topic_created(topic, user)

      entry = entries.last
      expect(entry.amount).to eq(5)
      expect(entry.entry_type).to eq(GamifiedShop::PointLedgerEntry::EVENT_REWARD)
      expect(entry.reference_type).to eq("Topic")
      expect(entry.reference_id).to eq(topic.id)
      expect(entry.description).to eq("topic_created")
      expect(balance).to eq(5)
    end

    it "awards nothing when the setting is 0" do
      SiteSetting.gamified_shop_topic_created_points = 0

      described_class.topic_created(topic, user)

      expect(entries).to be_empty
    end

    it "awards nothing when the plugin is disabled" do
      SiteSetting.gamified_shop_enabled = false

      described_class.topic_created(topic, user)

      expect(entries).to be_empty
    end

    it "awards nothing for private message topics" do
      pm_topic = Fabricate(:private_message_topic, user: user)

      described_class.topic_created(pm_topic, user)

      expect(entries).to be_empty
    end

    it "awards nothing to bots" do
      bot = Discourse.system_user
      bot_topic = Fabricate(:topic, user: bot)

      described_class.topic_created(bot_topic, bot)

      expect(entries(bot)).to be_empty
    end
  end

  describe ".reply_created" do
    it "awards the configured points and references the post" do
      described_class.reply_created(reply, user)

      entry = entries.last
      expect(entry.amount).to eq(2)
      expect(entry.entry_type).to eq(GamifiedShop::PointLedgerEntry::EVENT_REWARD)
      expect(entry.reference_type).to eq("Post")
      expect(entry.reference_id).to eq(reply.id)
      expect(entry.description).to eq("reply_created")
      expect(balance).to eq(2)
    end

    it "skips the OP post so topic creation is not double-awarded" do
      expect(first_post.post_number).to eq(1)

      described_class.topic_created(topic, user)
      described_class.reply_created(first_post, user)

      expect(entries.count).to eq(1)
      expect(entries.first.description).to eq("topic_created")
      expect(balance).to eq(5)
    end

    it "awards nothing when the setting is 0" do
      SiteSetting.gamified_shop_reply_created_points = 0

      described_class.reply_created(reply, user)

      expect(entries).to be_empty
    end

    it "awards nothing for whisper posts" do
      whisper = Fabricate(:post, topic: topic, user: user, post_type: Post.types[:whisper])

      described_class.reply_created(whisper, user)

      expect(entries).to be_empty
    end

    it "awards nothing for non-regular posts" do
      action_post =
        Fabricate(:post, topic: topic, user: user, post_type: Post.types[:moderator_action])

      described_class.reply_created(action_post, user)

      expect(entries).to be_empty
    end

    it "awards nothing for private message replies" do
      pm_topic = Fabricate(:private_message_topic, user: user)
      Fabricate(:post, topic: pm_topic, user: user)
      pm_reply = Fabricate(:post, topic: pm_topic, user: user)

      described_class.reply_created(pm_reply, user)

      expect(entries).to be_empty
    end

    it "awards nothing to bots" do
      bot = Discourse.system_user
      bot_reply = Fabricate(:post, topic: topic, user: bot)

      described_class.reply_created(bot_reply, bot)

      expect(entries(bot)).to be_empty
    end
  end

  describe ".like_created" do
    it "awards the configured points to the post author, not the liker" do
      post_action = like!(reply, from: liker)

      described_class.like_created(post_action)

      entry = entries.last
      expect(entry.amount).to eq(1)
      expect(entry.entry_type).to eq(GamifiedShop::PointLedgerEntry::EVENT_REWARD)
      expect(entry.reference_type).to eq("PostAction")
      expect(entry.reference_id).to eq(post_action.id)
      expect(entry.description).to eq("like_received")
      expect(balance).to eq(1)
      expect(entries(liker)).to be_empty
    end

    it "is a no-op when users like their own post" do
      described_class.like_created(like!(reply, from: user))

      expect(entries).to be_empty
    end

    it "awards nothing when the setting is 0" do
      SiteSetting.gamified_shop_like_received_points = 0

      described_class.like_created(like!(reply, from: liker))

      expect(entries).to be_empty
    end

    it "awards nothing for likes on whisper posts" do
      whisper = Fabricate(:post, topic: topic, user: user, post_type: Post.types[:whisper])

      described_class.like_created(like!(whisper, from: liker))

      expect(entries).to be_empty
    end

    it "awards nothing for likes on private message posts" do
      pm_topic = Fabricate(:private_message_topic, user: user)
      pm_post = Fabricate(:post, topic: pm_topic, user: user)

      described_class.like_created(like!(pm_post, from: liker))

      expect(entries).to be_empty
    end

    it "awards nothing when the recipient is a bot" do
      bot_post = Fabricate(:post, topic: topic, user: Discourse.system_user)

      described_class.like_created(like!(bot_post, from: liker))

      expect(entries(Discourse.system_user)).to be_empty
    end
  end

  describe ".like_destroyed" do
    it "reverses the like reward exactly once" do
      post_action = like!(reply, from: liker)
      described_class.like_created(post_action)
      expect(balance).to eq(1)

      described_class.like_destroyed(post_action)
      expect(balance).to eq(0)

      described_class.like_destroyed(post_action)
      expect(balance).to eq(0)
      expect(reversals.count).to eq(1)
      expect(reversals.first.reference_type).to eq("GamifiedShop::PointLedgerEntry")
      expect(reversals.first.reference_id).to eq(rewards.first.id)
      expect(reversals.first.description).to eq("like_removed")
    end
  end

  describe "daily earn cap" do
    before do
      SiteSetting.gamified_shop_daily_earn_cap = 10
      SiteSetting.gamified_shop_topic_created_points = 8
      SiteSetting.gamified_shop_reply_created_points = 5
    end

    it "clamps a credit to the remaining headroom" do
      described_class.topic_created(topic, user) # +8, headroom 2
      described_class.reply_created(reply, user) # 5 clamped to 2

      expect(rewards.last.amount).to eq(2)
      expect(balance).to eq(10)
    end

    it "creates no entry once the cap is reached" do
      described_class.topic_created(topic, user)
      described_class.reply_created(reply, user)
      expect(balance).to eq(10)

      another_reply = Fabricate(:post, topic: topic, user: user)
      expect { described_class.reply_created(another_reply, user) }.not_to change {
        entries.count
      }
      expect(balance).to eq(10)
    end

    it "does not cap when the cap is 0" do
      SiteSetting.gamified_shop_daily_earn_cap = 0

      described_class.topic_created(topic, user)
      described_class.reply_created(reply, user)

      expect(rewards.map(&:amount)).to eq([8, 5])
      expect(balance).to eq(13)
    end

    it "does not give headroom back when a reward is reversed" do
      described_class.topic_created(topic, user) # gross earned today: 8
      described_class.topic_destroyed(topic) # -8, gross stays 8
      expect(balance).to eq(0)

      described_class.reply_created(reply, user) # still clamped to 10 - 8 = 2

      expect(rewards.last.amount).to eq(2)
      expect(balance).to eq(2)
    end
  end

  describe ".post_destroyed / .post_recovered" do
    fab!(:liker2) { Fabricate(:user) }

    before do
      described_class.reply_created(reply, user) # +2
      described_class.like_created(like!(reply, from: liker)) # +1
      described_class.like_created(like!(reply, from: liker2)) # +1
    end

    it "reverses the reply reward and all like rewards exactly once" do
      expect(balance).to eq(4)

      described_class.post_destroyed(reply)
      expect(balance).to eq(0)
      expect(reversals.count).to eq(3)
      expect(reversals.map(&:amount)).to contain_exactly(-2, -1, -1)

      described_class.post_destroyed(reply)
      expect(balance).to eq(0)
      expect(reversals.count).to eq(3)
    end

    it "records each reversal against the original reward entry" do
      described_class.post_destroyed(reply)

      rewards.each do |reward|
        reversal = reversals.find_by(reference_id: reward.id)
        expect(reversal).to be_present
        expect(reversal.reference_type).to eq("GamifiedShop::PointLedgerEntry")
        expect(reversal.amount).to eq(-reward.amount)
        expect(reversal.description).to eq("post_deleted")
      end
    end

    it "restores the rewards exactly once on recovery" do
      described_class.post_destroyed(reply)
      expect(balance).to eq(0)

      described_class.post_recovered(reply)
      expect(balance).to eq(4)

      described_class.post_recovered(reply)
      expect(balance).to eq(4)
      expect(entries.count).to eq(9) # 3 rewards + 3 reversals + 3 restores
    end

    it "records each restore against the reversal it compensates" do
      described_class.post_destroyed(reply)
      described_class.post_recovered(reply)

      restores = rewards.where(reference_type: "GamifiedShop::PointLedgerEntry")
      expect(restores.count).to eq(3)
      expect(restores.map(&:reference_id)).to match_array(reversals.pluck(:id))
      expect(restores.map(&:description).uniq).to eq(["post_recovered"])
    end

    it "does nothing on recovery when nothing was reversed" do
      expect { described_class.post_recovered(reply) }.not_to change { entries.count }
      expect(balance).to eq(4)
    end

    it "nets to zero across a delete -> recover -> delete cycle" do
      described_class.post_destroyed(reply)
      described_class.post_recovered(reply)
      described_class.post_destroyed(reply)

      expect(balance).to eq(0)
      expect(entries.sum(:amount)).to eq(0)
      expect(reversals.count).to eq(6) # 3 original rewards + 3 restores reversed
    end
  end

  describe ".topic_destroyed / .topic_recovered" do
    before { described_class.topic_created(topic, user) } # +5

    it "reverses and restores the topic reward exactly once" do
      expect(balance).to eq(5)

      described_class.topic_destroyed(topic)
      expect(balance).to eq(0)
      described_class.topic_destroyed(topic)
      expect(balance).to eq(0)
      expect(reversals.count).to eq(1)

      described_class.topic_recovered(topic)
      expect(balance).to eq(5)
      described_class.topic_recovered(topic)
      expect(balance).to eq(5)
      expect(entries.count).to eq(3) # reward + reversal + restore
    end

    it "references the original reward from the reversal" do
      reward = rewards.first

      described_class.topic_destroyed(topic)

      reversal = reversals.first
      expect(reversal.reference_type).to eq("GamifiedShop::PointLedgerEntry")
      expect(reversal.reference_id).to eq(reward.id)
      expect(reversal.amount).to eq(-5)
      expect(reversal.description).to eq("topic_deleted")
    end

    it "nets to zero across a delete -> recover -> delete cycle" do
      described_class.topic_destroyed(topic)
      described_class.topic_recovered(topic)
      described_class.topic_destroyed(topic)

      expect(balance).to eq(0)
      expect(entries.sum(:amount)).to eq(0)
    end
  end
end
