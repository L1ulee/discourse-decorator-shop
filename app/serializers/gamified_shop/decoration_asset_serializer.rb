# frozen_string_literal: true

module GamifiedShop
  class DecorationAssetSerializer < ApplicationSerializer
    attributes :id, :name, :slot, :image_url, :animated, :style_preset

    def image_url
      object.image_url
    end

    def animated
      object.animated?
    end
  end
end
