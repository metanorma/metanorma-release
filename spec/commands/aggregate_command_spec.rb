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

RSpec.describe Metanorma::Release::AggregateCommand do
  describe ".build_config" do
    it "honours the config file's output_dir when the CLI omits it" do
      Dir.mktmpdir do |tmp|
        config_file = File.join(tmp, "metanorma.aggregate.yml")
        File.write(config_file, <<~YAML)
          source: github
          output_dir: _site/docs
          file_routing: flat
        YAML

        config = described_class.build_config(
          source: nil, organizations: [], topic: nil, repos: nil,
          channels: [], output_dir: nil, file_routing: nil,
          cache_dir: nil, data_dir: nil, include_drafts: nil,
          concurrency: nil, min_documents: nil, token: nil,
          create_zip: nil, config: config_file
        )

        expect(config.output_dir).to eq("_site/docs")
      end
    end

    it "falls back to the historical default when nothing sets output_dir" do
      Dir.mktmpdir do |tmp|
        config_file = File.join(tmp, "metanorma.aggregate.yml")
        File.write(config_file, "source: github\\n")

        config = described_class.build_config(
          source: nil, organizations: [], topic: nil, repos: nil,
          channels: [], output_dir: nil, file_routing: nil,
          cache_dir: nil, data_dir: nil, include_drafts: nil,
          concurrency: nil, min_documents: nil, token: nil,
          create_zip: nil, config: config_file
        )

        expect(config.output_dir).to eq("_site/cc")
      end
    end
  end
end
