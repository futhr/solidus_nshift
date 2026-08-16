# frozen_string_literal: true

class CreateSolidusNshiftDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :solidus_nshift_documents do |table|
      table.references :fulfillment, null: false, foreign_key: {to_table: :solidus_nshift_fulfillments}
      table.string :provider_document_id, null: false
      table.string :description
      table.string :format, null: false
      table.string :content_type, null: false
      table.timestamps
    end

    add_index :solidus_nshift_documents, [:fulfillment_id, :provider_document_id],
      unique: true, name: "index_nshift_documents_on_fulfillment_and_provider_id"
  end
end
