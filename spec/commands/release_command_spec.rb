# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Metanorma::Release::ReleaseCommand do
  it "runs pipeline with local platform publisher" do
    dir = Dir.mktmpdir
    begin
      config = described_class::Config.new(
        output_dir: dir, platform: "null",
        manifest: "nonexistent.yml", force: false,
        force_replace: [], channels: nil, concurrency: 4,
        token: nil, config_source: nil
      )
      result = described_class.new(config).call

      expect(result).to be_a(Metanorma::Release::ReleaseResult)
      expect(result.failed).to be_empty
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "passes channel override when channels specified" do
    dir = Dir.mktmpdir
    begin
      config = described_class::Config.new(
        output_dir: dir, platform: "null",
        manifest: "nonexistent.yml", force: false,
        force_replace: [], channels: ["public/default"],
        concurrency: 4, token: nil, config_source: nil
      )
      result = described_class.new(config).call

      expect(result).to be_a(Metanorma::Release::ReleaseResult)
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
