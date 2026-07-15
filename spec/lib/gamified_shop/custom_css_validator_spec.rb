# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamifiedShop::CustomCssValidator do
  def error(key)
    I18n.t("gamified_shop.css_errors.#{key}")
  end

  describe ".errors_for" do
    context "with valid declaration lists" do
      it "accepts a plain declaration list" do
        css = "color: #ff0000; font-weight: bold;\ntext-shadow: 0 0 2px #000;"

        expect(described_class.errors_for(css)).to eq([])
        expect(described_class.valid?(css)).to eq(true)
      end

      it "accepts url() pointing at a local upload" do
        css = "background-image: url('/uploads/default/original/1X/x.png'); background-size: cover;"

        expect(described_class.errors_for(css)).to eq([])
      end

      it "accepts custom properties" do
        expect(described_class.errors_for("--gds-x: 10px; color: var(--gds-x);")).to eq([])
      end

      it "accepts vendor-prefixed properties" do
        expect(
          described_class.errors_for("-webkit-background-clip: text; background-clip: text;"),
        ).to eq([])
      end

      it "accepts a trailing declaration without a semicolon" do
        expect(described_class.errors_for("color: red")).to eq([])
      end

      it "accepts blank input" do
        expect(described_class.errors_for(nil)).to eq([])
        expect(described_class.errors_for("")).to eq([])
      end
    end

    context "with hostile or malformed input" do
      it "rejects css over 4KB with only the size error" do
        css = "color: red;" * 400

        expect(css.bytesize).to be > described_class::MAX_BYTES
        expect(described_class.errors_for(css)).to eq([error(:too_long)])
      end

      it "rejects braces" do
        expect(described_class.errors_for("color: red; }")).to include(error(:forbidden_characters))
        expect(described_class.valid?(".evil { color: red; }")).to eq(false)
      end

      it "rejects at-rules" do
        expect(described_class.errors_for("@import '/uploads/x.css';")).to include(
          error(:forbidden_characters),
        )
        expect(described_class.errors_for("@media (max-width: 100px)")).to include(
          error(:forbidden_characters),
        )
      end

      it "rejects backslash escapes" do
        expect(described_class.errors_for("content: '\\2764';")).to eq(
          [error(:forbidden_characters)],
        )
      end

      it "rejects angle brackets" do
        expect(described_class.errors_for("color: <angle>")).to include(
          error(:forbidden_characters),
        )
      end

      it "rejects comments" do
        expect(described_class.errors_for("color: red; /* hide the rest */")).to include(
          error(:comments_not_allowed),
        )
      end

      it "rejects unbalanced quotes" do
        expect(described_class.errors_for("font-family: 'Comic")).to eq([error(:unbalanced_quotes)])
        expect(described_class.errors_for('content: "a;')).to include(error(:unbalanced_quotes))
      end

      it "rejects url() pointing off-site" do
        expect(described_class.errors_for("background: url(https://evil.example/x.png);")).to eq(
          [error(:external_url)],
        )
      end

      it "rejects data: urls" do
        css = "background-image: url(data:image/png;base64,iVBORw0KGgo=);"

        expect(described_class.errors_for(css)).to include(error(:external_url))
        expect(described_class.valid?(css)).to eq(false)
      end

      it "rejects local urls outside /uploads" do
        expect(described_class.errors_for("background: url('/assets/x.png');")).to eq(
          [error(:external_url)],
        )
      end

      it "rejects a malformed url() call" do
        expect(described_class.errors_for("background: url(/uploads/x.png")).to eq(
          [error(:malformed_url)],
        )
      end

      it "rejects bare text without a property/value colon" do
        expect(described_class.errors_for("this is not css")).to eq([error(:invalid_declaration)])
      end
    end
  end

  describe ".valid?" do
    it "mirrors errors_for" do
      expect(described_class.valid?("color: red;")).to eq(true)
      expect(described_class.valid?("color: red; }")).to eq(false)
    end
  end
end
