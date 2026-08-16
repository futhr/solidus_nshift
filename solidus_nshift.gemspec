# frozen_string_literal: true

require_relative "lib/solidus_nshift/version"

Gem::Specification.new do |spec|
  spec.name = "solidus_nshift"
  spec.version = SolidusNshift::VERSION
  spec.authors = ["Tobias Bohwalli and contributors"]
  spec.email = ["hi@futhr.io"]

  spec.summary = "nShift checkout and fulfillment integration for Solidus"
  spec.description = "A Solidus-native nShift adapter for checkout options, service points, Delivery booking, labels, tracking, and reconciliation."
  spec.homepage = "https://github.com/futhr/solidus_nshift"
  spec.license = "BSD-3-Clause"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.required_ruby_version = Gem::Requirement.new(">= 3.2")

  files = Dir.glob("{app,config,db,docs,lib}/**/*", File::FNM_DOTMATCH).select { |path| File.file?(path) }
  spec.files = files + %w[CHANGELOG.md CONTRIBUTING.md LICENSE.md README.md SECURITY.md]
  spec.require_paths = ["lib"]

  spec.add_dependency "solidus_core", ">= 4.6", "< 5"
  spec.add_dependency "solidus_support", ">= 0.12"

  spec.add_development_dependency "solidus_dev_support"
  spec.add_development_dependency "simplecov-lcov", "~> 0.9"
  spec.add_development_dependency "webmock", "~> 3.24"
end
