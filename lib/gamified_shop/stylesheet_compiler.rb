# frozen_string_literal: true

module GamifiedShop
  # Compiles every decoration asset's style into one stylesheet, served with
  # a content-hash URL (ADR-0002). All selectors are generated here - admin
  # input only ever contributes declaration bodies.
  #
  # Selector conventions consumed by the static plugin SCSS and the JS side:
  # - .gds-asset-<id>                 direct mounts (user card, profile, shop preview)
  # - article.gds-af-<id>             post article carrying an avatar frame
  # - article.gds-un-<id>             post article carrying a username style
  class StylesheetCompiler
    CACHE_KEY = "gamified-shop:compiled-stylesheet:v1"

    def self.css
      current["css"]
    end

    def self.digest
      current["digest"]
    end

    def self.expire!
      Discourse.cache.delete(CACHE_KEY)
    end

    def self.current
      Discourse.cache.fetch(CACHE_KEY) do
        compiled = compile
        { "css" => compiled, "digest" => Digest::SHA1.hexdigest(compiled) }
      end
    end

    def self.compile
      css = +"/* Gamified Decoration Shop - generated, do not edit */\n"
      DecorationAsset.includes(:upload).order(:id).each do |asset|
        css << rules_for(asset)
      end
      css
    end

    def self.rules_for(asset)
      case asset.slot
      when DecorationAsset::USERNAME_STYLE
        declarations = [
          StylePresets.declarations_for(asset).presence,
          asset.custom_css.presence,
        ].compact.join(" ")
        return "" if declarations.blank?
        ".gds-asset-#{asset.id}, article.gds-un-#{asset.id} .names .first a" \
          " { #{declarations} }\n"
      when DecorationAsset::AVATAR_FRAME
        url = safe_url(asset.image_url)
        return "" if url.blank?
        rules =
          ".gds-asset-#{asset.id}, article.gds-af-#{asset.id} .topic-avatar" \
            " { --gds-frame-image: url('#{url}'); }\n"
        if asset.animated?
          rules << "@media (prefers-reduced-motion: reduce) {" \
            " .gds-asset-#{asset.id}, article.gds-af-#{asset.id} .topic-avatar" \
            " { --gds-frame-image: none; } }\n"
        end
        rules
      when DecorationAsset::USER_CARD_BACKGROUND
        url = safe_url(asset.image_url)
        return "" if url.blank?
        rules = ".gds-asset-#{asset.id} { --gds-card-bg-image: url('#{url}'); }\n"
        if asset.animated?
          rules << "@media (prefers-reduced-motion: reduce) {" \
            " .gds-asset-#{asset.id} { --gds-card-bg-image: none; } }\n"
        end
        rules
      else
        ""
      end
    end

    def self.safe_url(url)
      return nil if url.blank?
      url.gsub("'", "%27").gsub("\\", "%5C")
    end
  end
end
