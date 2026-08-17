# frozen_string_literal: true

module SolidusNshift
  class RateSelectionsController < Spree::BaseController
    protect_from_forgery unless: -> { request.format.json? }

    rescue_from SolidusNshift::ValidationError, with: :unprocessable
    rescue_from CanCan::AccessDenied, with: :forbidden

    def update
      selection = RateSelection.includes(shipping_rate: {shipment: :order}).find(params[:id])
      order = selection.shipping_rate.shipment.order
      authorize! :update, order, order_token
      order.with_lock do
        order.reload
        selection.shipping_rate.reload
        raise ValidationError, "completed orders cannot change nShift pickup points" if order.completed?
        unless selection.shipping_rate.selected?
          raise ValidationError, "nShift pickup point belongs to an unselected shipping rate"
        end

        selection.select_pickup_point!(params.require(:pickup_point_id))
        SelectionValidator.new(shipment: selection.shipping_rate.shipment).call
      end

      render json: {
        id: selection.id,
        pickup_point_id: selection.selected_pickup_point_id,
        pickup_point: selection.selected_pickup_point
      }
    end

    private

    def order_token
      request.headers["X-Spree-Order-Token"].presence || params[:order_token]
    end

    def forbidden
      head :forbidden
    end

    def unprocessable(error)
      render json: {error: error.message}, status: :unprocessable_content
    end
  end
end
