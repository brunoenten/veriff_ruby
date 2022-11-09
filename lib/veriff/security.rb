# frozen_string_literal: true

module Veriff
  module Security
    def generate_signature(options)
      data = options[:signature] || options[:body]
      OpenSSL::HMAC.hexdigest('SHA256', configuration.api_secret, data)
    end

    def validate_signature(body, signature)
      generate_signature(body: body) == signature
    end
  end
end
