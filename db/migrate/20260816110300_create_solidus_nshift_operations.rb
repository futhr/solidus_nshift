# frozen_string_literal: true

class CreateSolidusNshiftOperations < ActiveRecord::Migration[7.0]
  def change
    create_table :solidus_nshift_operations do |table|
      table.references :fulfillment, null: false, foreign_key: {to_table: :solidus_nshift_fulfillments}
      table.string :kind, null: false
      table.string :status, null: false, default: "pending"
      table.string :request_fingerprint, null: false, limit: 64
      table.string :provider_resource_id
      table.string :provider_request_id
      table.string :provider_code
      table.string :error_class
      table.text :error_message
      table.integer :attempts, null: false, default: 0
      table.datetime :started_at
      table.datetime :finished_at
      table.timestamps
    end

    add_index :solidus_nshift_operations, [:fulfillment_id, :kind],
      unique: true, name: "index_nshift_operations_on_fulfillment_and_kind"
    add_index :solidus_nshift_operations, :status
  end
end
