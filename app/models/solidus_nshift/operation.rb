# frozen_string_literal: true

module SolidusNshift
  class Operation < ::Spree::Base
    KINDS = %w[checkout_partial delivery_booking delivery_cancel].freeze
    STATUSES = %w[pending in_progress succeeded rejected unknown].freeze

    self.table_name = "solidus_nshift_operations"

    belongs_to :fulfillment, class_name: "SolidusNshift::Fulfillment", inverse_of: :operations

    validates :kind, inclusion: {in: KINDS}, uniqueness: {scope: :fulfillment_id}
    validates :status, inclusion: {in: STATUSES}
    validates :request_fingerprint, format: {with: /\A[0-9a-f]{64}\z/}

    def claim!
      with_lock do
        return false if status == "succeeded"
        raise ReconciliationRequired, "nShift operation outcome must be reconciled" if %w[in_progress unknown].include?(status)

        update!(
          status: "in_progress",
          attempts: attempts + 1,
          started_at: Time.current,
          finished_at: nil,
          error_class: nil,
          error_message: nil,
          provider_code: nil
        )
      end
      true
    end

    def mark_succeeded!(provider_resource_id:, provider_request_id: nil)
      update!(
        status: "succeeded",
        provider_resource_id:,
        provider_request_id:,
        error_class: nil,
        error_message: nil,
        provider_code: nil,
        finished_at: Time.current
      )
    end

    def mark_rejected!(error)
      update_error!(error, status: "rejected")
    end

    def mark_unknown!(error)
      update_error!(error, status: "unknown")
    end

    private

    def update_error!(error, status:)
      update!(
        status:,
        error_class: error.class.name,
        error_message: error.message.to_s.first(2_000),
        provider_request_id: error.respond_to?(:provider_request_id) ? error.provider_request_id : nil,
        provider_code: error.respond_to?(:provider_code) ? error.provider_code : nil,
        finished_at: Time.current
      )
    end
  end
end
