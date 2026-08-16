# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["SOLIDUS_PREFERENCES_MASTER_KEY"] ||= "0" * 32

require "spec_helper"
require File.expand_path("dummy/config/environment", __dir__)
require "solidus_dev_support/rspec/rails_helper"
require "solidus_nshift/engine" unless defined?(SolidusNshift::Engine)

unless ActiveRecord::Base.connection.data_source_exists?("spree_stores")
  ActiveRecord::Schema.verbose = false
  load Rails.root.join("db/schema.rb")
end

SolidusDevSupport::TestingSupport::Factories.load_for(SolidusNshift::Engine)

RSpec.configure do |config|
  config.before do
    SolidusNshift.reset_configuration!
  end
end
