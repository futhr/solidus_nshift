# frozen_string_literal: true

class HardenSolidusNshiftInvariants < ActiveRecord::Migration[7.0]
  def change
    add_column :solidus_nshift_operations, :revision, :integer, null: false, default: 1
    reversible do |direction|
      direction.up do
        remove_index :solidus_nshift_operations, [:fulfillment_id, :kind],
          name: "index_nshift_operations_on_fulfillment_and_kind"
        add_index :solidus_nshift_operations, [:fulfillment_id, :kind, :revision],
          unique: true, name: "index_nshift_operations_on_fulfillment_kind_revision"
      end
      direction.down do
        ensure_single_revision_per_kind!
        remove_index :solidus_nshift_operations, [:fulfillment_id, :kind, :revision],
          name: "index_nshift_operations_on_fulfillment_kind_revision"
        add_index :solidus_nshift_operations, [:fulfillment_id, :kind],
          unique: true, name: "index_nshift_operations_on_fulfillment_and_kind"
      end
    end

    add_index :solidus_nshift_fulfillments, [:connection_id, :checkout_partial_shipment_id],
      unique: true, name: "index_nshift_fulfillments_on_connection_and_checkout_id"
    add_index :solidus_nshift_fulfillments, [:connection_id, :provider_shipment_id],
      unique: true, name: "index_nshift_fulfillments_on_connection_and_shipment_id"
    add_index :solidus_nshift_fulfillments, [:connection_id, :shipment_data_uuid],
      unique: true, name: "index_nshift_fulfillments_on_connection_and_tracking_uuid"
    add_index :solidus_nshift_fulfillments, :rate_selection_id,
      unique: true, name: "index_nshift_fulfillments_on_rate_selection"

    add_check_constraint :solidus_nshift_rate_selections, "amount >= 0",
      name: "nshift_rate_selections_nonnegative_amount"
    add_check_constraint :solidus_nshift_fulfillments,
      "state IN ('unbooked', 'booking', 'partial_created', 'booked', 'reconciliation_pending', 'rejected', 'canceled')",
      name: "nshift_fulfillments_valid_state"
    add_check_constraint :solidus_nshift_fulfillments,
      "tracking_status IS NULL OR tracking_status IN ('unknown', 'created', 'in_transit', 'out_for_delivery', 'exception', 'delivered', 'canceled')",
      name: "nshift_fulfillments_valid_tracking_status"
    add_check_constraint :solidus_nshift_operations,
      "kind IN ('checkout_partial', 'delivery_booking', 'delivery_cancel')",
      name: "nshift_operations_valid_kind"
    add_check_constraint :solidus_nshift_operations,
      "status IN ('pending', 'in_progress', 'succeeded', 'rejected', 'unknown')",
      name: "nshift_operations_valid_status"
    add_check_constraint :solidus_nshift_operations, "attempts >= 0",
      name: "nshift_operations_nonnegative_attempts"
    add_check_constraint :solidus_nshift_operations, "revision > 0",
      name: "nshift_operations_positive_revision"
    add_check_constraint :solidus_nshift_documents, "format IN ('pdf', 'zpl')",
      name: "nshift_documents_valid_format"
    add_check_constraint :solidus_nshift_documents,
      "content_type IN ('application/pdf', 'application/octet-stream')",
      name: "nshift_documents_valid_content_type"
    add_check_constraint :solidus_nshift_tracking_events,
      "status IN ('unknown', 'created', 'in_transit', 'out_for_delivery', 'exception', 'delivered', 'canceled')",
      name: "nshift_tracking_events_valid_status"
  end

  private

  def ensure_single_revision_per_kind!
    duplicate_count = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM (
        SELECT fulfillment_id, kind
        FROM solidus_nshift_operations
        GROUP BY fulfillment_id, kind
        HAVING COUNT(*) > 1
      ) duplicate_operations
    SQL
    return if duplicate_count.zero?

    raise ActiveRecord::IrreversibleMigration,
      "cannot remove nShift operation revisions after retries have been recorded"
  end
end
