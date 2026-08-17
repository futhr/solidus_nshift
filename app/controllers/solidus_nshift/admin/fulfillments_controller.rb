# frozen_string_literal: true

module SolidusNshift
  module Admin
    class FulfillmentsController < BaseController
      before_action :load_fulfillment, except: :index

      def index
        @fulfillments = Fulfillment.includes(:connection, shipment: :order)
          .order(created_at: :desc)
          .page(params[:page])
          .per(50)
      end

      def show
        @operations = @fulfillment.operations.order(:created_at)
        @documents = @fulfillment.documents.order(:created_at)
        @tracking_events = @fulfillment.tracking_events.order(occurred_at: :desc)
      end

      def book
        unless bookable?
          return invalid_action("Only unbooked, rejected, or incomplete Delivery fulfillments can be booked")
        end

        enqueue(
          SolidusNshift.configuration.book_shipment_job.call,
          [@fulfillment.shipment_id],
          "book_shipment",
          "nShift booking queued"
        )
      end

      def reconcile
        unless %w[booking reconciliation_pending].include?(@fulfillment.state)
          return invalid_action("Only booking or pending fulfillments can be reconciled")
        end

        enqueue(ReconcileBookingJob, [@fulfillment.id], "reconcile_booking", "nShift reconciliation queued")
      end

      def sync_tracking
        unless @fulfillment.connection.tracking_enabled? && @fulfillment.provider_shipment_id.present?
          return invalid_action("Tracking is not available for this fulfillment")
        end

        enqueue(
          SolidusNshift.configuration.sync_tracking_job.call,
          [@fulfillment.id],
          "sync_tracking",
          "nShift tracking sync queued"
        )
      end

      def cancel
        return invalid_action("Only booked fulfillments can be canceled") unless @fulfillment.booked?

        enqueue(CancelFulfillmentJob, [@fulfillment.id], "cancel_fulfillment", "nShift cancellation queued")
      end

      def refresh_documents
        return invalid_action("Documents are not available before booking") if @fulfillment.provider_shipment_id.blank?

        enqueue(RefreshDocumentsJob, [@fulfillment.id], "refresh_documents", "nShift document refresh queued")
      end

      private

      def model_class
        SolidusNshift::Fulfillment
      end

      def load_fulfillment
        @fulfillment = Fulfillment.find(params[:id])
      end

      def bookable?
        %w[unbooked rejected].include?(@fulfillment.state) ||
          (@fulfillment.state == "partial_created" && @fulfillment.connection.delivery_enabled?)
      end

      def enqueue(job_class, arguments, operation, notice)
        queued = JobEnqueuer.call(
          job_class:,
          arguments:,
          operation:,
          metadata: {fulfillment_id: @fulfillment.id, connection_id: @fulfillment.connection_id}
        )
        if queued
          redirect_to admin_fulfillment_path(@fulfillment), notice:
        else
          redirect_to admin_fulfillment_path(@fulfillment), alert: "nShift job could not be queued; retry after checking the queue backend"
        end
      end

      def invalid_action(message)
        redirect_to admin_fulfillment_path(@fulfillment), alert: message
      end
    end
  end
end
