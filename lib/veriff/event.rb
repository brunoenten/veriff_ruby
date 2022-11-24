# frozen_string_literal: true

module Veriff
  class Event < Model
    def initialize(body)
      super(Parser.call(body, :json))
    end
  end
end
