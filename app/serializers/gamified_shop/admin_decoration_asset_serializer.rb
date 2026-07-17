# frozen_string_literal: true

module GamifiedShop
  class AdminDecorationAssetSerializer < DecorationAssetSerializer
    attributes :upload_id, :style_params, :custom_css, :in_use

    def in_use
      object.in_use?
    end
  end
end
