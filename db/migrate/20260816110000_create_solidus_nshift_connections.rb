# frozen_string_literal: true

class CreateSolidusNshiftConnections < ActiveRecord::Migration[7.0]
  def change
    create_table :solidus_nshift_connections do |table|
      table.references :store, null: false, foreign_key: {to_table: :spree_stores}
      table.string :name, null: false
      table.text :preferences
      table.boolean :active, null: false, default: true
      table.boolean :checkout_enabled, null: false, default: true
      table.boolean :delivery_enabled, null: false, default: false
      table.boolean :tracking_enabled, null: false, default: false
      table.timestamps
    end

    add_index :solidus_nshift_connections, [:store_id, :name], unique: true
  end
end
