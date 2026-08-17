# frozen_string_literal: true

module SolidusNshift
  module Admin
    class ConnectionsController < BaseController
      SECRET_PARAMETERS = %w[
        preferred_checkout_client_secret preferred_delivery_api_key_id
        preferred_delivery_api_key_secret preferred_tracking_client_secret
      ].freeze

      before_action :load_connection, only: %i[edit update destroy]

      def index
        @connections = Connection.includes(:store).order(:store_id, :name)
      end

      def new
        @connection = Connection.new(store: current_store)
      end

      def create
        @connection = Connection.new(connection_params)
        if @connection.save
          redirect_to admin_connections_path, notice: "nShift connection created"
        else
          render :new, status: :unprocessable_content
        end
      end

      def edit
      end

      def update
        if @connection.update(connection_params)
          redirect_to admin_connections_path, notice: "nShift connection updated"
        else
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        if @connection.destroy
          redirect_to admin_connections_path, notice: "nShift connection deleted"
        else
          redirect_to admin_connections_path, alert: @connection.errors.full_messages.to_sentence
        end
      end

      private

      def model_class
        SolidusNshift::Connection
      end

      def load_connection
        @connection = Connection.find(params[:id])
      end

      def connection_params
        permitted = params.require(:solidus_nshift_connection).permit(
          :store_id, :name, :active, :checkout_enabled, :delivery_enabled, :tracking_enabled,
          :preferred_checkout_client_id, :preferred_checkout_client_secret, :preferred_checkout_connection_id,
          :preferred_delivery_api_key_id, :preferred_delivery_api_key_secret, :preferred_delivery_developer_id,
          :preferred_delivery_sender_quick_id, :preferred_delivery_sender_name,
          :preferred_delivery_sender_address1, :preferred_delivery_sender_address2,
          :preferred_delivery_sender_zipcode, :preferred_delivery_sender_city,
          :preferred_delivery_sender_country, :preferred_delivery_sender_phone,
          :preferred_delivery_sender_email, :preferred_delivery_label_format, :preferred_delivery_label_media,
          :preferred_delivery_test_mode,
          :preferred_tracking_client_id, :preferred_tracking_client_secret
        )
        SECRET_PARAMETERS.each { |name| permitted.delete(name) if permitted[name].blank? }
        permitted
      end
    end
  end
end
