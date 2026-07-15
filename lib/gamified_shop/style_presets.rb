# frozen_string_literal: true

module GamifiedShop
  # Factory-shipped username style presets (PRD 6.4). Admin-configurable
  # surface is the parameter values only; every parameter is validated to a
  # strict color format, so nothing free-form ever reaches the stylesheet.
  class StylePresets
    COLOR = /\A#(\h{3}|\h{4}|\h{6}|\h{8})\z/

    # preset key => { param name => :color }
    PRESETS = {
      "username_solid" => { "color" => :color },
      "username_gradient" => { "from" => :color, "to" => :color },
      "username_glow" => { "color" => :color },
      "username_rainbow" => {},
    }.freeze

    def self.keys
      PRESETS.keys
    end

    # Returns translated error messages (empty when valid).
    def self.validate(preset, params)
      schema = PRESETS[preset]
      return [error(:unknown_preset)] if schema.nil?

      params = {} if params.blank?
      return [error(:invalid_params)] unless params.is_a?(Hash)

      errors = []
      params.each_key do |key|
        errors << error(:unknown_param) unless schema.key?(key.to_s)
      end
      schema.each_key do |key|
        value = params[key.to_s] || params[key.to_sym]
        unless value.is_a?(String) && value.match?(COLOR)
          errors << error(:invalid_color)
        end
      end
      errors.uniq
    end

    # Declarations for a pre-validated asset. Values are known-safe colors.
    def self.declarations_for(asset)
      params = asset.style_params || {}
      case asset.style_preset
      when "username_solid"
        "color: #{params["color"]} !important;"
      when "username_gradient"
        "background-image: linear-gradient(90deg, #{params["from"]}, #{params["to"]});" \
          " -webkit-background-clip: text; background-clip: text; color: transparent !important;"
      when "username_glow"
        "color: #{params["color"]} !important;" \
          " text-shadow: 0 0 4px #{params["color"]}, 0 0 10px #{params["color"]};"
      when "username_rainbow"
        "animation: gds-rainbow-text 3s linear infinite;"
      else
        ""
      end
    end

    def self.error(key)
      I18n.t("gamified_shop.style_errors.#{key}")
    end
  end
end
