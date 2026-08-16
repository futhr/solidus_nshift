# frozen_string_literal: true

require "digest"
require "json"

module SolidusNshift
  module PayloadFingerprint
    module_function

    def call(payload)
      Digest::SHA256.hexdigest(JSON.generate(payload))
    end
  end
end
