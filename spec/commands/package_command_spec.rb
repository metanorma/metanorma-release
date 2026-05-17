# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Metanorma::Release::PackageCommand do
  it "runs pipeline with null publisher and returns result" do
    dir = Dir.mktmpdir
    begin
      config = described_class::Config.new(
        output_dir: dir, dest: "dist",
        manifest: "nonexistent.yml", config_source: nil
      )
      result = described_class.new(config).call

      expect(result).to be_a(Metanorma::Release::ReleaseResult)
      expect(result.failed).to be_empty
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "loads config from config_source when provided" do
    config_dir = Dir.mktmpdir
    output_dir = Dir.mktmpdir
    begin
      config_file = File.join(config_dir, "config.yml")
      File.write(config_file, "channels:\n  - public\n")

      config = described_class::Config.new(
        output_dir: output_dir, dest: "dist",
        manifest: "nonexistent.yml", config_source: config_file
      )
      result = described_class.new(config).call

      expect(result).to be_a(Metanorma::Release::ReleaseResult)
    ensure
      FileUtils.rm_rf(config_dir)
      FileUtils.rm_rf(output_dir)
    end
  end
end
