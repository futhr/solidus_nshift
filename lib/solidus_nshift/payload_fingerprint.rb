# frozen_string_literal: true

require "digest"
require "json"

module SolidusNshift
  module PayloadFingerprint
    module_function

    def call(payload)
      Digest::SHA256.hexdigest(JSON.generate(canonicalize(payload)))
    end

    def canonicalize(value)
      case value
      when Hash
        value.sort_by { |key, _item| key.to_s }.to_h do |key, item|
          [key.to_s, canonicalize(item)]
        end
      when Array
        value.map { |item| canonicalize(item) }
      else
        value
      end
    end
    private_class_method :canonicalize
  end
end
