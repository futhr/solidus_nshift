# frozen_string_literal: true

require "rspec"
require "digest"
require "fileutils"
require "open3"
require "rubygems/package"
require "tmpdir"

RSpec.describe "the package verifier" do
  let(:source_root) { File.expand_path("../..", __dir__) }
  let(:source_specification) { load_specification(source_root) }
  let(:package_specification) do
    source_specification.dup.tap do |specification|
      specification.metadata = source_specification.metadata.dup
    end
  end
  let(:archive_path) do
    File.join(@fixture_root, "pkg", "#{source_specification.full_name}.gem")
  end

  around do |example|
    Dir.mktmpdir("solidus-nshift-package-verifier-") do |root|
      @fixture_root = root
      copy_source_files
      example.run
    end
  end

  it "accepts a freshly built archive matching the current source" do
    package = build_package

    expect(package.contents).to match_array(source_specification.files)
    output, status = run_verifier

    expect(status.success?).to be(true), output
    expect(output).to include("Verified #{File.basename(archive_path)}:")
    expect(output).to include("SHA256 #{Digest::SHA256.file(archive_path).hexdigest}")
  end

  it "rejects a same-version archive with stale source bytes" do
    relative_path = "lib/solidus_nshift/reference.rb"
    source_bytes = File.binread(File.join(@fixture_root, relative_path))
    package = build_with_stale_payload(relative_path, source_bytes)
    extracted_root = File.join(@fixture_root, "extracted")
    package.extract_files(extracted_root)

    expect(File.binread(File.join(@fixture_root, relative_path))).to eq(source_bytes)
    expect(File.binread(File.join(extracted_root, relative_path))).not_to eq(source_bytes)
    expect_rejection
  end

  it "rejects a same-version archive with a stale runtime dependency requirement" do
    package_specification.dependencies.delete_if { |dependency| dependency.name == "solidus_core" }
    package_specification.add_runtime_dependency "solidus_core", ">= 4.7", "< 5"
    package = build_package

    source_dependency = source_specification.runtime_dependencies.find { |dependency| dependency.name == "solidus_core" }
    packaged_dependency = package.spec.runtime_dependencies.find { |dependency| dependency.name == "solidus_core" }
    expect(packaged_dependency.requirement).not_to eq(source_dependency.requirement)
    expect_rejection
  end

  it "rejects a same-version archive with stale source metadata" do
    package_specification.metadata["source_code_uri"] = "#{source_specification.homepage}/tree/stale-package-fixture"
    package = build_package

    expect(package.spec.metadata.fetch("source_code_uri"))
      .not_to eq(source_specification.metadata.fetch("source_code_uri"))
    expect_rejection
  end

  it "rejects a same-version archive whose name differs from the source gemspec" do
    package_specification.name = "solidus_nshift_package_fixture"
    package = build_package

    expect(package.spec.name).not_to eq(source_specification.name)
    expect_rejection
  end

  it "rejects a same-version archive with a stale required Ruby version" do
    package_specification.required_ruby_version = Gem::Requirement.new(">= 3.3")
    package = build_package

    expect(package.spec.required_ruby_version).not_to eq(source_specification.required_ruby_version)
    expect_rejection
  end

  it "rejects a same-version archive with an extra allowed-path source file" do
    relative_path = "lib/solidus_nshift/package_fixture.rb"
    specification = package_specification
    path = File.join(@fixture_root, relative_path)

    begin
      File.binwrite(path, "# stale package fixture\n")
      specification.files += [relative_path]
      package = build_package
    ensure
      FileUtils.rm_f(path)
    end

    expect(package.contents - source_specification.files).to eq([relative_path])
    expect(File.exist?(path)).to be(false)
    expect_rejection
  end

  it "rejects a same-version archive missing a non-required source file" do
    relative_path = "docs/operations.md"
    expect(source_specification.files).to include(relative_path)
    package_specification.files -= [relative_path]
    package = build_package

    expect(source_specification.files - package.contents).to eq([relative_path])
    expect(File.binread(File.join(@fixture_root, relative_path)))
      .to eq(File.binread(File.join(source_root, relative_path)))
    expect_rejection
  end

  def load_specification(root)
    specification = Gem::Specification.load(File.join(root, "solidus_nshift.gemspec"))
    raise "Could not load fixture gemspec from #{root}" unless specification

    specification
  end

  def copy_source_files
    files = source_specification.files + %w[solidus_nshift.gemspec bin/check_package]
    files.each do |relative_path|
      destination = File.join(@fixture_root, relative_path)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(File.join(source_root, relative_path), destination)
    end
  end

  def build_package
    FileUtils.mkdir_p(File.dirname(archive_path))
    filename = Dir.chdir(@fixture_root) { Gem::Package.build(package_specification) }
    FileUtils.mv(File.join(@fixture_root, filename), archive_path)
    package = Gem::Package.new(archive_path)

    expect { package.verify }.not_to raise_error
    expect_existing_admission_properties(package)
    package
  end

  def build_with_stale_payload(relative_path, source_bytes)
    path = File.join(@fixture_root, relative_path)

    begin
      File.binwrite(path, source_bytes + "\n# stale package fixture\n")
      build_package
    ensure
      File.binwrite(path, source_bytes)
    end
  end

  def expect_existing_admission_properties(package)
    expect(package.spec.version).to eq(source_specification.version)
    expect(package.spec.licenses).to eq(["BSD-3-Clause"])
    expect(package.spec.metadata.fetch("rubygems_mfa_required")).to eq("true")
    expect(package.contents).to include(*required_package_files)
    migrations = package.contents.grep(%r{\Adb/migrate/.*\.rb\z})
    expect(migrations.size).to be >= 7
    expect(migrations).to match_array(source_specification.files.grep(%r{\Adb/migrate/.*\.rb\z}))
    expect(package.contents.reject { |path| allowed_package_file?(path) }).to be_empty
    expect(package.contents.grep(/(?:credentials|master\.key|\.env)(?:\.|\/|\z)/)).to be_empty
  end

  def required_package_files
    %w[
      LICENSE.md README.md CHANGELOG.md SECURITY.md
      lib/solidus_nshift.rb lib/solidus_nshift/engine.rb config/routes.rb
      lib/generators/solidus_nshift/install/install_generator.rb
      lib/generators/solidus_nshift/install/templates/solidus_nshift.rb
    ]
  end

  def allowed_package_file?(path)
    %w[CHANGELOG.md CONTRIBUTING.md LICENSE.md README.md SECURITY.md].include?(path) ||
      /\A(?:app|config|db|docs|lib)\/.*\.(?:rb|erb|yml|yaml|md)\z/.match?(path)
  end

  def run_verifier
    environment = {"RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil}
    Open3.capture2e(environment, Gem.ruby, File.join(@fixture_root, "bin/check_package"), chdir: @fixture_root)
  end

  def expect_rejection
    output, status = run_verifier

    expect(status.exitstatus).to eq(1), output
    expect(output).not_to include("Verified ")
  end
end
