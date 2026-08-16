# frozen_string_literal: true

module SolidusNshift
  module OAuth
    Token = Data.define(:value, :expires_at) do
      def valid?(at:, safety_margin:)
        !value.to_s.empty? && expires_at > at + safety_margin
      end
    end
  end
end
