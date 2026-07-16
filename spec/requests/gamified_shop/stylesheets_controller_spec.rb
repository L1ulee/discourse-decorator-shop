# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::StylesheetsController do
  fab!(:asset) do
    Fabricate(
      :gamified_shop_decoration_asset,
      style_preset: "username_solid",
      style_params: {
        "color" => "#ff0000",
      },
    )
  end

  before do
    SiteSetting.gamified_shop_enabled = true
    GamifiedShop::StylesheetCompiler.expire!
  end

  # Rails re-serializes Cache-Control and does not preserve directive order
  # (it emits "max-age=..., public, immutable"), so compare the directive set.
  def cache_control_directives
    response.headers["Cache-Control"].split(",").map(&:strip)
  end

  describe "GET /gamified-shop/stylesheet/:digest.css" do
    let(:digest) { GamifiedShop::StylesheetCompiler.digest }

    it "returns 404 when the plugin is disabled" do
      SiteSetting.gamified_shop_enabled = false

      get "/gamified-shop/stylesheet/#{digest}.css"

      expect(response.status).to eq(404)
    end

    it "serves CSS anonymously" do
      get "/gamified-shop/stylesheet/#{digest}.css"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/css")
    end

    it "sends an immutable cache header when the digest matches" do
      get "/gamified-shop/stylesheet/#{digest}.css"

      expect(response.status).to eq(200)
      expect(cache_control_directives).to contain_exactly("public", "max-age=31556952", "immutable")
    end

    it "sends a short cache header for a stale digest" do
      get "/gamified-shop/stylesheet/deadbeef.css"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/css")
      expect(cache_control_directives).to contain_exactly("public", "max-age=60")
    end

    it "contains the .gds-asset-<id> rule for a username style asset" do
      get "/gamified-shop/stylesheet/#{digest}.css"

      expect(response.status).to eq(200)
      expect(response.body).to include(".gds-asset-#{asset.id}")
      expect(response.body).to include(".gds-un-#{asset.id}")
      expect(response.body).to include("color: #ff0000 !important;")
    end

    it "recompiles (new digest) after an asset changes" do
      old_digest = digest

      asset.update!(style_params: { "color" => "#00ff00" })
      # The model's after_commit also expires the cache; do it explicitly so
      # this spec does not depend on commit-callback timing in transactional
      # tests.
      GamifiedShop::StylesheetCompiler.expire!
      new_digest = GamifiedShop::StylesheetCompiler.digest
      expect(new_digest).not_to eq(old_digest)

      get "/gamified-shop/stylesheet/#{new_digest}.css"

      expect(response.status).to eq(200)
      expect(cache_control_directives).to contain_exactly("public", "max-age=31556952", "immutable")
      expect(response.body).to include("color: #00ff00 !important;")
    end
  end
end
