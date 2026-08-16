# frozen_string_literal: true

module SolidusNshift
  class SelectionValidator
    def initialize(shipment:, at: Time.current)
      @shipment = shipment
      @at = at
    end

    def call
      rate = @shipment.selected_shipping_rate
      selection = rate&.nshift_selection
      calculator = rate&.shipping_method&.calculator
      unless selection && calculator.is_a?(Spree::Calculator::Shipping::NshiftCheckout)
        raise ValidationError, "shipment does not have a selected nShift rate"
      end
      unless selection.selection_complete?
        raise ValidationError, "selected nShift pickup option requires a service point"
      end

      request = Solidus::PackageSerializer.new(package: @shipment.to_package, calculator:).call
      unless selection.valid_for?(digest: request.context_digest, at: @at)
        raise StaleSessionError, "selected nShift rate no longer matches the shipment"
      end

      selection
    end
  end
end
