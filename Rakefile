# frozen_string_literal: true

require "bundler/gem_tasks"
require "solidus_dev_support/rake_tasks"

SolidusDevSupport::RakeTasks.install

Rake::Task["extension:test_app"].enhance do
  # The upstream dummy generator omits the legacy backend's asset entrypoints.
  manifest = File.expand_path("spec/dummy/app/assets/config/manifest.js", __dir__)
  if File.exist?(manifest) && SolidusSupport.backend_available?
    contents = File.read(manifest)
    %w[spree/backend/all.js spree/backend/all.css].each do |asset|
      directive = "//= link #{asset}"
      File.open(manifest, "a") { |file| file.puts(directive) } unless contents.include?(directive)
    end
  end
end

# solidus_core's dummy-app task still calls the Rails.env= writer removed in
# Rails 7.2. Keep the compatibility shim scoped to development rake tasks.
unless Rails.respond_to?(:env=)
  Rails.define_singleton_method(:env=) do |environment|
    ENV["RAILS_ENV"] = environment.to_s
    remove_instance_variable(:@_env) if instance_variable_defined?(:@_env)
  end
end

task default: "extension:specs"
