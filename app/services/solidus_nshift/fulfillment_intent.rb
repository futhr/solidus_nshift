# frozen_string_literal: true

module SolidusNshift
  class FulfillmentIntent
    def initialize(shipment:)
      @shipment = shipment
    end

    def call
      existing = Fulfillment.find_by(shipment: @shipment)
      return existing if existing && provider_state_already_persisted?(existing)

      selection = SelectionValidator.new(shipment: @shipment).call
      record = existing || Fulfillment.find_or_create_by!(shipment: @shipment) do |candidate|
        candidate.connection = selection.connection
        candidate.rate_selection = selection
        candidate.merchant_reference = Reference.for(@shipment)
      end
      validate!(record, selection)
    rescue ActiveRecord::RecordNotUnique
      record = Fulfillment.find_by(shipment: @shipment)
      unless record
        raise ShipmentConflictError,
          "nShift fulfillment intent conflicts with a different shipment"
      end

      validate!(record, selection)
    end

    private

    def provider_state_already_persisted?(record)
      record.checkout_partial_shipment_id.present? || record.provider_shipment_id.present?
    end

    def validate!(record, selection)
      if record.rate_selection_id != selection.id || record.connection_id != selection.connection_id
        raise ShipmentConflictError, "shipment already has a different nShift fulfillment intent"
      end

      record
    end
  end
end
