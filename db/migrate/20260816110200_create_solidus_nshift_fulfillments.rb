# frozen_string_literal: true

class CreateSolidusNshiftFulfillments < ActiveRecord::Migration[7.0]
  def change
    create_table :solidus_nshift_fulfillments do |table|
      table.references :shipment, null: false, foreign_key: {to_table: :spree_shipments}, index: {unique: true}
      table.references :connection, null: false, foreign_key: {to_table: :solidus_nshift_connections}
      table.references :rate_selection, null: false, foreign_key: {to_table: :solidus_nshift_rate_selections}
      table.string :merchant_reference, null: false
      table.string :state, null: false, default: "unbooked"
      table.string :checkout_partial_shipment_id
      table.string :provider_shipment_id
      table.string :provider_status
      table.string :tracking_number
      table.string :shipment_data_uuid
      table.string :tracking_status
      table.string :last_error_class
      table.string :last_error_code
      table.text :last_error_message
      table.datetime :last_reconciled_at
      table.datetime :tracking_synced_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps
    end

    add_index :solidus_nshift_fulfillments, [:connection_id, :merchant_reference],
      unique: true, name: "index_nshift_fulfillments_on_connection_and_reference"
    add_index :solidus_nshift_fulfillments, :provider_shipment_id
    add_index :solidus_nshift_fulfillments, :shipment_data_uuid
    add_index :solidus_nshift_fulfillments, :state
  end
end
