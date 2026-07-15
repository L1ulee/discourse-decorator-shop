# frozen_string_literal: true

module GamifiedShop
  # Behavior earning + reversal (PRD 6.2, plan A: site settings).
  #
  # Reward entries reference their trigger (Topic / Post / PostAction).
  # Reversals reference the reward ledger entry they undo; restores (post
  # undelete) reference the reversal they compensate. Both are capped to one
  # per target by partial unique indexes, so the whole chain is idempotent
  # under repeated delete/recover cycles.
  class Earnings
    LEDGER_REF = "GamifiedShop::PointLedgerEntry"

    class << self
      def topic_created(topic, user)
        return unless enabled?
        return if topic.blank? || topic.private_message?
        return unless eligible_user?(user)
        award(
          user,
          SiteSetting.gamified_shop_topic_created_points,
          reference: topic,
          kind: "topic_created",
        )
      end

      def reply_created(post, user)
        return unless enabled?
        return if post.blank? || post.post_number == 1
        return unless eligible_post?(post)
        return unless eligible_user?(user)
        award(
          user,
          SiteSetting.gamified_shop_reply_created_points,
          reference: post,
          kind: "reply_created",
        )
      end

      def like_created(post_action)
        return unless enabled?
        return unless like?(post_action)
        post = post_action.post
        return if post.blank? || !eligible_post?(post)
        recipient = post.user
        return unless eligible_user?(recipient)
        return if post_action.user_id == post.user_id
        award(
          recipient,
          SiteSetting.gamified_shop_like_received_points,
          reference: post_action,
          kind: "like_received",
        )
      end

      def like_destroyed(post_action)
        return unless enabled?
        return unless like?(post_action)
        reverse_trigger(post_action, kind: "like_removed")
      end

      def post_destroyed(post)
        return unless enabled?
        return if post.blank?
        reverse_trigger(post, kind: "post_deleted")
        like_actions_for(post).each { |pa| reverse_trigger(pa, kind: "post_deleted") }
      end

      def post_recovered(post)
        return unless enabled?
        return if post.blank?
        restore_trigger(post, kind: "post_recovered", restore_kinds: ["post_deleted"])
        like_actions_for(post).each do |pa|
          restore_trigger(pa, kind: "post_recovered", restore_kinds: ["post_deleted"])
        end
      end

      # Deleting a topic hides every reply with it, so their rewards (and the
      # rewards for likes on them) are clawed back too. Replies that were
      # individually deleted beforehand are already reversed (idempotent).
      def topic_destroyed(topic)
        return unless enabled?
        return if topic.blank?
        reverse_trigger(topic, kind: "topic_deleted")
        live_replies_of(topic).find_each do |post|
          reverse_trigger(post, kind: "topic_deleted")
          like_actions_for(post).each { |pa| reverse_trigger(pa, kind: "topic_deleted") }
        end
      end

      def topic_recovered(topic)
        return unless enabled?
        return if topic.blank?
        restore_trigger(topic, kind: "topic_recovered", restore_kinds: ["topic_deleted"])
        live_replies_of(topic).find_each do |post|
          restore_trigger(post, kind: "topic_recovered", restore_kinds: ["topic_deleted"])
          like_actions_for(post).each do |pa|
            restore_trigger(pa, kind: "topic_recovered", restore_kinds: ["topic_deleted"])
          end
        end
      end

      private

      def enabled?
        SiteSetting.gamified_shop_enabled
      end

      def like?(post_action)
        post_action.present? && post_action.post_action_type_id == PostActionType.types[:like]
      end

      def eligible_user?(user)
        user.present? && user.id > 0 && !user.bot?
      end

      def eligible_post?(post)
        return false if post.whisper?
        return false if post.post_type != Post.types[:regular]
        topic = post.topic
        topic.present? && !topic.private_message?
      end

      def live_replies_of(topic)
        Post.where(topic_id: topic.id, deleted_at: nil).where("post_number > 1")
      end

      # with_deleted on purpose: PostDestroyer trashes a post's like
      # PostActions (sets deleted_at) as it fires :post_destroyed, so
      # Trashable's default scope would hide the very likes whose rewards must
      # be clawed back. Reversal/restore stay correct because reverse_trigger
      # is idempotent and restore_trigger is filtered by restore_kinds.
      def like_actions_for(post)
        PostAction.with_deleted.where(
          post_id: post.id,
          post_action_type_id: PostActionType.types[:like],
        )
      end

      # Daily cap: gross credits per day, clamped to the remaining headroom,
      # computed under the account row lock so concurrent awards cannot
      # overshoot. Cap 0 means "no cap".
      def award(user, points, reference:, kind:)
        return if points.to_i <= 0
        cap = SiteSetting.gamified_shop_daily_earn_cap
        PointsLedger.apply!(
          user_id: user.id,
          entry_type: PointLedgerEntry::EVENT_REWARD,
          reference: reference,
          description: kind,
        ) do |_account|
          if cap > 0
            remaining = cap - PointLedgerEntry.earned_today(user.id)
            remaining <= 0 ? nil : [points, remaining].min
          else
            points
          end
        end
      end

      # All reward entries attached to a trigger, following the
      # reward -> reversal -> restore chain to any depth.
      def reward_entries_for(trigger)
        rewards =
          PointLedgerEntry.where(
            entry_type: PointLedgerEntry::EVENT_REWARD,
            reference_type: trigger.class.name,
            reference_id: trigger.id,
          ).to_a
        frontier = rewards
        while frontier.any?
          reversals =
            PointLedgerEntry.where(
              entry_type: PointLedgerEntry::EVENT_REVERSAL,
              reference_type: LEDGER_REF,
              reference_id: frontier.map(&:id),
            ).to_a
          break if reversals.empty?
          frontier =
            PointLedgerEntry.where(
              entry_type: PointLedgerEntry::EVENT_REWARD,
              reference_type: LEDGER_REF,
              reference_id: reversals.map(&:id),
            ).to_a
          rewards.concat(frontier)
        end
        rewards
      end

      def reverse_trigger(trigger, kind:)
        rewards = reward_entries_for(trigger)
        return if rewards.empty?
        reversed_ids =
          PointLedgerEntry
            .where(
              entry_type: PointLedgerEntry::EVENT_REVERSAL,
              reference_type: LEDGER_REF,
              reference_id: rewards.map(&:id),
            )
            .pluck(:reference_id)
            .to_set

        rewards.each do |entry|
          next if reversed_ids.include?(entry.id)
          begin
            PointsLedger.apply!(
              user_id: entry.user_id,
              amount: -entry.amount,
              entry_type: PointLedgerEntry::EVENT_REVERSAL,
              reference: entry,
              description: kind,
            )
          rescue ActiveRecord::RecordNotUnique
            # Raced with another reversal of the same entry: already done.
          end
        end
      end

      # Restores skip the daily cap on purpose: they give back points that
      # were already earned (and clawed back), not new earnings.
      #
      # restore_kinds guards against cross-restoring: recovering a post must
      # only undo reversals written by that post's deletion — never
      # "like_removed" reversals (the like is still removed) and never
      # "post_deleted" reversals of a reply that was individually deleted
      # before its topic was deleted.
      def restore_trigger(trigger, kind:, restore_kinds:)
        rewards = reward_entries_for(trigger)
        return if rewards.empty?
        reversals =
          PointLedgerEntry.where(
            entry_type: PointLedgerEntry::EVENT_REVERSAL,
            reference_type: LEDGER_REF,
            reference_id: rewards.map(&:id),
            description: restore_kinds,
          ).to_a
        return if reversals.empty?
        restored_ids =
          PointLedgerEntry
            .where(
              entry_type: PointLedgerEntry::EVENT_REWARD,
              reference_type: LEDGER_REF,
              reference_id: reversals.map(&:id),
            )
            .pluck(:reference_id)
            .to_set

        reversals.each do |reversal|
          next if restored_ids.include?(reversal.id)
          begin
            PointsLedger.apply!(
              user_id: reversal.user_id,
              amount: reversal.amount.abs,
              entry_type: PointLedgerEntry::EVENT_REWARD,
              reference: reversal,
              description: kind,
            )
          rescue ActiveRecord::RecordNotUnique
            # Raced with another restore of the same reversal: already done.
          end
        end
      end
    end
  end
end
