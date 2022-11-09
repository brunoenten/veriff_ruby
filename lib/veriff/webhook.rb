# frozen_string_literal: true
require 'rack'
module Veriff
  # Rack application that can be mounted in rails to create webhooks routes
  # Inspired by https://github.com/modernistik/parse-stack/blob/master/lib/parse/webhooks.rb
  class Webhooks
    ENDPOINTS = %i[decision event].freeze
    class << self
      def route(endpoint, &block)
        unless ENDPOINTS.include?(endpoint) && block.respond_to?(:call)
          raise ArgumentError, "Invalid Webhook registration for endpoint #{endpoint}"
        end

        @routes ||= {}
        @routes[endpoint] = block
      end

      def call(env)
        request = Rack::Request.new env
        response = Rack::Response.new

        unless request.content_type.present? && request.content_type.include?('application/json')
          response.write "Invalid content-type format. Should be application/json."
          response.status = 400
          return response.finish
        end

        unless request.has_header?('HTTP_X_HMAC_SIGNATURE')
          response.write "Missing signature header x-hmac-signature."
          response.status = 400
          return response.finish
        end

        endpoint = request.path.split('/')[2].to_sym
        Rails.logger.debug("endpoint: #{endpoint}")

        unless @routes[endpoint]
          response.write "No defined callback for this endpoint."
          response.status = 500
          return response.finish
        end

        request.body.rewind
        body = request.body.read
        puts body
        signature = request.get_header('HTTP_X_HMAC_SIGNATURE')
        Rails.logger.debug("signature: #{signature}")

        unless Veriff::validate_signature(body, signature)
          response.write "Invalid signature."
          response.status = 403
          return response.finish
        end

        klass = Object.const_get('Veriff::' + endpoint.to_s.capitalize)
        object = klass.new(Parser.call(body, :json))
        if @routes[endpoint].call(object)
          response.write "Success"
        else
          response.write "Error while executing callback."
          response.status = 500
        end
        response.finish
      end
    end
  end
end

