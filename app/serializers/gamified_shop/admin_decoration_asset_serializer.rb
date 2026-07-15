# frozen_string_literal: true

module GamifiedShop
  class AdminDecorationAssetSerializer < DecorationAssetSerializer
    attributes :upload_id, :style_params, :custom_css, :destroyable

    def destroyable
      object.destroyable?
    end
  end
end
