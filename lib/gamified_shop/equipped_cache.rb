# frozen_string_literal: true

module GamifiedShop
  # Per-user "what is equipped" lookup used by serializers on hot paths
  # (post stream). Invalidated by UserDecoration commits; expiry in the MVP
  # only happens through revoke/refund, both of which write UserDecoration
  # rows, so the cache never serves a stale revoked decoration.
  class EquippedCache
    EXPIRY = 10.minutes

    def self.for_user(user_id)
      Discourse.cache.fetch(cache_key(user_id), expires_in: EXPIRY) do
        rows =
          UserDecoration
            .displayable
            .where(user_id: user_id)
            .joins(:decoration_asset)
            .pluck("gamified_shop_decoration_assets.slot", :decoration_asset_id)
        rows.to_h
      end
    end

    def self.invalidate(user_id)
      Discourse.cache.delete(cache_key(user_id))
    end

    def self.cache_key(user_id)
      "gamified-shop:equipped:v1:#{user_id}"
    end
  end
end
