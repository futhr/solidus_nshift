# frozen_string_literal: true

class CreateSolidusNshiftTrackingEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :solidus_nshift_tracking_events do |table|
      table.references :fulfillment, null: false, foreign_key: {to_table: :solidus_nshift_fulfillments}
      table.string :external_event_id, null: false
      table.string :code, null: false
      table.string :status, null: false
      table.datetime :occurred_at, null: false
      table.text :description
      table.json :provider_metadata, null: false, default: {}
      table.timestamps
    end

    add_index :solidus_nshift_tracking_events, [:fulfillment_id, :external_event_id],
      unique: true, name: "index_nshift_events_on_fulfillment_and_external_id"
    add_index :solidus_nshift_tracking_events, [:fulfillment_id, :occurred_at],
      name: "index_nshift_events_on_fulfillment_and_time"
  end
end
