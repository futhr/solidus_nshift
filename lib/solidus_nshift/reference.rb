# frozen_string_literal: true

module SolidusNshift
  module Reference
    module_function

    def for(shipment, revision: 1)
      store_code = shipment.order.store.code.to_s.gsub(/[^0-9A-Za-z_.-]/, "-").first(40)
      shipment_code = (shipment.number.presence || shipment.id).to_s.gsub(/[^0-9A-Za-z_.-]/, "-").first(80)
      raise ValidationError, "shipment must be persisted before nShift booking" if shipment_code.empty?
      normalized_revision = Integer(revision)
      raise ValidationError, "nShift booking revision must be positive" unless normalized_revision.positive?

      "solidus:#{store_code}:#{shipment_code}:#{normalized_revision}"
    rescue ArgumentError, TypeError
      raise ValidationError, "nShift booking revision must be an integer"
    end
  end
end
