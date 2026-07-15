# frozen_string_literal: true

module GamifiedShop
  # Domain error carrying an i18n-able code (gamified_shop.errors.<code>).
  class ShopError < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code.to_s)
    end
  end
end
