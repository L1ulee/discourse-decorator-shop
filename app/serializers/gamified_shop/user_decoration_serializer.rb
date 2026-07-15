# frozen_string_literal: true

module GamifiedShop
  class UserDecorationSerializer < ApplicationSerializer
    attributes :id,
               :user_id,
               :decoration_asset_id,
               :source,
               :equipped,
               :expires_at,
               :displayable

    has_one :decoration_asset,
            serializer: DecorationAssetSerializer,
            embed: :objects

    def displayable
      object.displayable?
    end
  end
end
