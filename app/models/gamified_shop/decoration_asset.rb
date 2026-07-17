# frozen_string_literal: true

module GamifiedShop
  class DecorationAsset < ActiveRecord::Base
    self.table_name = "gamified_shop_decoration_assets"

    AVATAR_FRAME = "avatar_frame"
    USERNAME_STYLE = "username_style"
    USER_CARD_BACKGROUND = "user_card_background"
    SLOTS = [AVATAR_FRAME, USERNAME_STYLE, USER_CARD_BACKGROUND].freeze
    IMAGE_SLOTS = [AVATAR_FRAME, USER_CARD_BACKGROUND].freeze

    belongs_to :upload, optional: true
    has_many :shop_items, class_name: "GamifiedShop::ShopItem", foreign_key: :decoration_asset_id
    has_many :user_decorations,
             class_name: "GamifiedShop::UserDecoration",
             foreign_key: :decoration_asset_id

    validates :name, presence: true, length: { maximum: 200 }
    validates :slot, inclusion: { in: SLOTS }
    validate :validate_slot_requirements
    validate :validate_style

    after_commit { GamifiedShop::StylesheetCompiler.expire! }

    def image_slot?
      IMAGE_SLOTS.include?(slot)
    end

    def image_url
      upload&.url
    end

    def animated?
      upload&.animated? || false
    end

    # True when a shop item sells the asset or a user owns it. Deletion is
    # still allowed — AssetsController#destroy cascades the cleanup (removes
    # it from users, unlinks shop items) — so this only drives the admin
    # "in use" label and the delete-confirmation warning.
    def in_use?
      shop_items.exists? || user_decorations.exists?
    end

    private

    def validate_slot_requirements
      if image_slot?
        errors.add(:upload_id, :blank) if upload_id.blank?
      elsif style_preset.blank? && custom_css.blank?
        errors.add(:style_preset, :blank)
      end
    end

    def validate_style
      if style_preset.present?
        if slot != USERNAME_STYLE
          errors.add(:style_preset, :invalid)
        else
          GamifiedShop::StylePresets
            .validate(style_preset, style_params || {})
            .each { |e| errors.add(:style_params, e) }
        end
      end

      if custom_css.present?
        if slot != USERNAME_STYLE
          errors.add(:custom_css, :invalid)
        else
          GamifiedShop::CustomCssValidator
            .errors_for(custom_css)
            .each { |e| errors.add(:custom_css, e) }
        end
      end
    end
  end
end
