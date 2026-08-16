# frozen_string_literal: true

module SolidusNshift
  module Admin
    class FulfillmentsController < BaseController
      before_action :load_fulfillment, except: :index

      def index
        @fulfillments = Fulfillment.includes(:connection, shipment: :order).order(created_at: :desc).limit(250)
      end

      def show
        @operations = @fulfillment.operations.order(:created_at)
        @documents = @fulfillment.documents.order(:created_at)
        @tracking_events = @fulfillment.tracking_events.order(occurred_at: :desc)
      end

      def book
        BookShipmentJob.perform_later(@fulfillment.shipment_id)
        redirect_to admin_fulfillment_path(@fulfillment), notice: "nShift booking queued"
      end

      def reconcile
        ReconcileBookingJob.perform_later(@fulfillment.id)
        redirect_to admin_fulfillment_path(@fulfillment), notice: "nShift reconciliation queued"
      end

      def sync_tracking
        SyncTrackingJob.perform_later(@fulfillment.id)
        redirect_to admin_fulfillment_path(@fulfillment), notice: "nShift tracking sync queued"
      end

      def cancel
        CancelFulfillmentJob.perform_later(@fulfillment.id)
        redirect_to admin_fulfillment_path(@fulfillment), notice: "nShift cancellation queued"
      end

      def refresh_documents
        RefreshDocumentsJob.perform_later(@fulfillment.id)
        redirect_to admin_fulfillment_path(@fulfillment), notice: "nShift document refresh queued"
      end

      private

      def load_fulfillment
        @fulfillment = Fulfillment.find(params[:id])
      end
    end
  end
end
