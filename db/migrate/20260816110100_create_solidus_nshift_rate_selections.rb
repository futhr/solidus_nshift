# frozen_string_literal: true

class CreateSolidusNshiftRateSelections < ActiveRecord::Migration[7.0]
  def change
    create_table :solidus_nshift_rate_selections do |table|
      table.references :shipping_rate, null: false, type: primary_key_type(:spree_shipping_rates),
        foreign_key: {to_table: :spree_shipping_rates}, index: {unique: true}
      table.references :connection, null: false, foreign_key: {to_table: :solidus_nshift_connections}
      table.string :session_id, null: false
      table.string :external_option_id, null: false
      table.string :service_code, null: false
      table.string :carrier_code
      table.string :carrier_name
      table.string :label, null: false
      table.decimal :amount, null: false, precision: 12, scale: 4
      table.string :currency, null: false, limit: 3
      table.string :delivery_estimate
      table.string :context_digest, null: false, limit: 64
      table.json :pickup_points, null: false
      table.string :selected_pickup_point_id
      table.json :selected_pickup_point, null: false
      table.json :provider_metadata, null: false
      table.datetime :session_expires_at, null: false
      table.timestamps
    end

    add_index :solidus_nshift_rate_selections, :context_digest
    add_index :solidus_nshift_rate_selections, [:connection_id, :session_id], name: "index_nshift_selections_on_connection_and_session"
  end

  private

  def primary_key_type(table_name)
    connection.columns(table_name).find { |column| column.name == "id" }.type
  end
end
