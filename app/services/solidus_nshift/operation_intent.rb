# frozen_string_literal: true

module SolidusNshift
  class OperationIntent
    def initialize(fulfillment:, kind:, fingerprint:)
      @fulfillment = fulfillment
      @kind = kind
      @fingerprint = fingerprint
    end

    def call
      current = @fulfillment.latest_operation(@kind)
      if current && current.status != "rejected"
        validate!(current)
        return current
      end

      revision = current ? current.revision + 1 : 1
      operation = @fulfillment.operations.find_or_create_by!(kind: @kind, revision:) do |record|
        record.request_fingerprint = @fingerprint
      end
      validate!(operation)
    rescue ActiveRecord::RecordNotUnique
      validate!(@fulfillment.operations.find_by!(kind: @kind, revision:))
    end

    private

    def validate!(operation)
      if operation.request_fingerprint != @fingerprint
        raise ShipmentConflictError, "nShift mutation payload conflicts with its persisted operation revision"
      end

      operation
    end
  end
end
