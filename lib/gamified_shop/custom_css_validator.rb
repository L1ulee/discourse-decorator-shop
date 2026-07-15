# frozen_string_literal: true

module GamifiedShop
  # Guardrails for admin-authored decoration CSS (ADR-0002).
  #
  # Input is a bare declaration list ("color: red; text-shadow: ...") that the
  # compiler wraps in a plugin-owned selector. The validator makes escaping
  # that block structurally impossible:
  # - no braces (cannot close the block or open another)
  # - no at-rules (@import, @media, ...)
  # - no backslash escapes (kills escape smuggling)
  # - no comments and no unbalanced quotes (cannot swallow the rest of the
  #   compiled stylesheet)
  # - url() may only point at a local upload
  # - hard size cap
  class CustomCssValidator
    MAX_BYTES = 4096
    FORBIDDEN_CHARS = /[{}@\\<>]/
    # Functions that load resources from bare strings (no url() call), which
    # would sidestep the url() allowlist below.
    FORBIDDEN_FUNCTIONS = /(?:image-set|cross-fade|element|paint|src)\s*\(/i
    # No absolute or protocol-relative references anywhere - local uploads
    # never need "http:", "https:" or "//".
    FORBIDDEN_SEQUENCES = %r{https?:|//}i
    URL_OPEN = /url\s*\(/i
    URL_CALL = /url\s*\(\s*(['"]?)([^)'"]*)\1\s*\)/i
    ALLOWED_URL_PREFIX = %r{\A/uploads/}
    DECLARATION = /\A\s*(?:--)?-?[a-zA-Z][a-zA-Z0-9-]*\s*:\s*\S/

    def self.valid?(css)
      errors_for(css).empty?
    end

    # Returns an array of translated error messages (empty when valid).
    def self.errors_for(css)
      css = css.to_s
      errors = []
      return [error(:too_long)] if css.bytesize > MAX_BYTES

      errors << error(:forbidden_characters) if css.match?(FORBIDDEN_CHARS)
      errors << error(:forbidden_functions) if css.match?(FORBIDDEN_FUNCTIONS)
      errors << error(:external_url) if css.match?(FORBIDDEN_SEQUENCES)
      errors << error(:comments_not_allowed) if css.include?("/*") || css.include?("*/")
      if css.count('"').odd? || css.count("'").odd?
        errors << error(:unbalanced_quotes)
      end

      url_opens = css.scan(URL_OPEN).size
      url_calls = css.scan(URL_CALL)
      if url_calls.size != url_opens
        errors << error(:malformed_url)
      elsif url_calls.any? { |_, path| !path.to_s.match?(ALLOWED_URL_PREFIX) }
        errors << error(:external_url)
      end

      css.split(";").each do |declaration|
        next if declaration.strip.empty?
        unless declaration.match?(DECLARATION)
          errors << error(:invalid_declaration)
          break
        end
      end

      errors.uniq
    end

    def self.error(key)
      I18n.t("gamified_shop.css_errors.#{key}")
    end
  end
end
