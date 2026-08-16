# frozen_string_literal: true

require "time"

module SolidusNshift
  module ShipmentData
    class Event < Data.define(:external_id, :code, :status, :occurred_at, :description, :raw_code)
      TERMINAL = %w[delivered canceled].freeze
      PRECEDENCE = {
        "unknown" => 0,
        "created" => 1,
        "in_transit" => 2,
        "out_for_delivery" => 3,
        "exception" => 3,
        "delivered" => 4,
        "canceled" => 4
      }.freeze

      def terminal?
        TERMINAL.include?(status)
      end

      def precedence
        PRECEDENCE.fetch(status, 0)
      end
    end
  end
end
