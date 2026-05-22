# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Metanorma::Release::AggregateCommand do
  it "runs aggregation pipeline and returns result" do
    source_dir = Dir.mktmpdir
    output_dir = Dir.mktmpdir
    begin
      config = described_class::Config.new(
        source: "local:#{source_dir}", organizations: [], topic: "test",
        repos: nil, channels: [], output_dir: output_dir,
        file_routing: "by-document", cache_dir: nil,
        include_drafts: false, concurrency: 4, min_documents: 0,
        token: nil, create_zip: nil, display_categories: []
      )
      result = described_class.new(config).call

      expect(result).to be_a(Metanorma::Release::AggregationPipeline::Result)
      expect(result.publications).to be_empty
    ensure
      FileUtils.rm_rf(source_dir)
      FileUtils.rm_rf(output_dir)
    end
  end

  it "does not raise when zip flag is nil" do
    source_dir = Dir.mktmpdir
    output_dir = Dir.mktmpdir
    begin
      config = described_class::Config.new(
        source: "local:#{source_dir}", organizations: [], topic: "test",
        repos: nil, channels: [], output_dir: output_dir,
        file_routing: "by-document", cache_dir: nil,
        include_drafts: false, concurrency: 4, min_documents: 0,
        token: nil, create_zip: nil, display_categories: []
      )

      expect { described_class.new(config).call }.not_to raise_error
    ensure
      FileUtils.rm_rf(source_dir)
      FileUtils.rm_rf(output_dir)
    end
  end
end
