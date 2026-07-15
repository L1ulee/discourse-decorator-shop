# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::StylePresets do
  def error(key)
    I18n.t("gamified_shop.style_errors.#{key}")
  end

  def build_asset(preset, params)
    GamifiedShop::DecorationAsset.new(
      name: "Test",
      slot: "username_style",
      style_preset: preset,
      style_params: params,
    )
  end

  describe ".keys" do
    it "exposes the factory-shipped presets" do
      expect(described_class.keys).to contain_exactly(
        "username_solid",
        "username_gradient",
        "username_glow",
        "username_rainbow",
      )
    end
  end

  describe ".validate" do
    it "rejects an unknown preset" do
      expect(described_class.validate("username_sparkle", {})).to eq([error(:unknown_preset)])
    end

    it "rejects params that are not a hash" do
      expect(described_class.validate("username_solid", "red")).to eq([error(:invalid_params)])
    end

    it "rejects a parameter the preset does not accept" do
      expect(
        described_class.validate("username_solid", { "color" => "#fff", "size" => "#fff" }),
      ).to eq([error(:unknown_param)])
      expect(described_class.validate("username_rainbow", { "color" => "#fff" })).to eq(
        [error(:unknown_param)],
      )
    end

    it "rejects values that are not strict hex colors" do
      expect(described_class.validate("username_solid", { "color" => "red" })).to eq(
        [error(:invalid_color)],
      )
      expect(described_class.validate("username_solid", { "color" => "#ggg" })).to eq(
        [error(:invalid_color)],
      )
      expect(described_class.validate("username_solid", { "color" => "#12345" })).to eq(
        [error(:invalid_color)],
      )
    end

    it "rejects missing required parameters" do
      expect(described_class.validate("username_solid", {})).to eq([error(:invalid_color)])
      expect(described_class.validate("username_gradient", { "from" => "#fff" })).to eq(
        [error(:invalid_color)],
      )
    end

    it "accepts 3, 4, 6 and 8 digit hex colors" do
      %w[#abc #abcd #aabbcc #aabbccdd].each do |color|
        expect(described_class.validate("username_solid", { "color" => color })).to eq([])
      end
    end

    it "accepts symbol keys" do
      expect(described_class.validate("username_solid", { color: "#abc" })).to eq([])
    end

    it "accepts a fully valid gradient" do
      expect(
        described_class.validate("username_gradient", { "from" => "#111111", "to" => "#222222" }),
      ).to eq([])
    end

    it "accepts the parameterless rainbow preset" do
      expect(described_class.validate("username_rainbow", {})).to eq([])
      expect(described_class.validate("username_rainbow", nil)).to eq([])
    end
  end

  describe ".declarations_for" do
    it "renders username_solid" do
      asset = build_asset("username_solid", { "color" => "#112233" })

      expect(described_class.declarations_for(asset)).to eq("color: #112233 !important;")
    end

    it "renders username_gradient" do
      asset = build_asset("username_gradient", { "from" => "#111111", "to" => "#222222" })

      expect(described_class.declarations_for(asset)).to eq(
        "background-image: linear-gradient(90deg, #111111, #222222);" \
          " -webkit-background-clip: text; background-clip: text; color: transparent !important;",
      )
    end

    it "renders username_glow" do
      asset = build_asset("username_glow", { "color" => "#aabbcc" })

      expect(described_class.declarations_for(asset)).to eq(
        "color: #aabbcc !important; text-shadow: 0 0 4px #aabbcc, 0 0 10px #aabbcc;",
      )
    end

    it "renders username_rainbow" do
      asset = build_asset("username_rainbow", {})

      expect(described_class.declarations_for(asset)).to eq(
        "animation: gds-rainbow-text 3s linear infinite;",
      )
    end

    it "renders nothing for an unknown preset" do
      asset = build_asset("username_sparkle", {})

      expect(described_class.declarations_for(asset)).to eq("")
    end
  end
end
