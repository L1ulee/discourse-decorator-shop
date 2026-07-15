# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::StylesheetCompiler do
  before { described_class.expire! }

  describe ".compile" do
    it "generates username style rules for the direct mount and the post article" do
      asset = Fabricate(:gamified_shop_decoration_asset, style_params: { "color" => "#ff0000" })

      css = described_class.compile

      expect(css).to include(
        ".gds-asset-#{asset.id}, article.gds-un-#{asset.id} .names .first a" \
          " { color: #ff0000 !important; }",
      )
    end

    it "appends custom_css after the preset declarations" do
      asset = Fabricate(:gamified_shop_decoration_asset, custom_css: "letter-spacing: 1px;")

      css = described_class.compile

      expect(css).to include(
        ".gds-asset-#{asset.id}, article.gds-un-#{asset.id} .names .first a" \
          " { color: #ff0000 !important; letter-spacing: 1px; }",
      )
    end

    it "emits a rule for username assets that only have custom_css" do
      asset =
        Fabricate(
          :gamified_shop_decoration_asset,
          style_preset: nil,
          style_params: {},
          custom_css: "letter-spacing: 2px;",
        )

      css = described_class.compile

      expect(css).to include(
        ".gds-asset-#{asset.id}, article.gds-un-#{asset.id} .names .first a" \
          " { letter-spacing: 2px; }",
      )
    end

    it "generates avatar frame rules exposing the frame image variable" do
      asset =
        Fabricate(:gamified_shop_avatar_frame_asset, upload: Fabricate(:upload, animated: false))

      css = described_class.compile

      expect(css).to include(
        ".gds-asset-#{asset.id}, article.gds-af-#{asset.id} .topic-avatar" \
          " { --gds-frame-image: url('#{asset.image_url}'); }",
      )
      expect(css).not_to include("prefers-reduced-motion")
    end

    it "adds a prefers-reduced-motion override for animated avatar frames" do
      asset =
        Fabricate(:gamified_shop_avatar_frame_asset, upload: Fabricate(:upload, animated: true))

      css = described_class.compile

      expect(css).to include("@media (prefers-reduced-motion: reduce)")
      expect(css).to include(
        ".gds-asset-#{asset.id}, article.gds-af-#{asset.id} .topic-avatar" \
          " { --gds-frame-image: none; }",
      )
    end

    it "generates user card background rules" do
      asset =
        Fabricate(:gamified_shop_card_background_asset, upload: Fabricate(:upload, animated: false))

      css = described_class.compile

      expect(css).to include(
        ".gds-asset-#{asset.id} { --gds-card-bg-image: url('#{asset.image_url}'); }",
      )
      expect(css).not_to include("prefers-reduced-motion")
    end

    it "adds a prefers-reduced-motion override for animated card backgrounds" do
      asset =
        Fabricate(:gamified_shop_card_background_asset, upload: Fabricate(:upload, animated: true))

      css = described_class.compile

      expect(css).to include(
        "@media (prefers-reduced-motion: reduce) {" \
          " .gds-asset-#{asset.id} { --gds-card-bg-image: none; } }",
      )
    end
  end

  describe ".digest" do
    it "is stable while assets are unchanged" do
      Fabricate(:gamified_shop_decoration_asset)
      described_class.expire!

      expect(described_class.digest).to eq(described_class.digest)
    end

    it "changes when an asset changes" do
      asset = Fabricate(:gamified_shop_decoration_asset)
      described_class.expire!
      old_digest = described_class.digest

      asset.update!(style_params: { "color" => "#00ff00" })
      # The model's after_commit hook expires the cache in production; do it
      # explicitly here so the test does not depend on callback timing.
      described_class.expire!

      expect(described_class.digest).not_to eq(old_digest)
      expect(described_class.css).to include("color: #00ff00 !important;")
    end
  end

  describe ".expire!" do
    it "busts the cached stylesheet" do
      asset = Fabricate(:gamified_shop_decoration_asset)
      described_class.expire!

      selector = ".gds-asset-#{asset.id}, article.gds-un-#{asset.id} .names .first a"
      expect(described_class.css).to include(selector)

      # delete_all skips callbacks, so the cached stylesheet stays stale
      # until expire! is called.
      GamifiedShop::DecorationAsset.where(id: asset.id).delete_all
      expect(described_class.css).to include(selector)

      described_class.expire!
      expect(described_class.css).not_to include(selector)
    end
  end
end
