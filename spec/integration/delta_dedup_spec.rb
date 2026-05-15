# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "shared_contexts"

RSpec.describe "Delta dedup across runs", type: :integration do
  include_context "with released documents"

  let(:cache_dir) { Dir.mktmpdir }
  after { FileUtils.rm_rf(cache_dir) }

  def run_aggregation(output_dir, cache_dir, released_dir)
    discoverer = Metanorma::Release::PlatformFactory::StaticDiscoverer.new(
      repos: [Metanorma::Release::RepoRef.new(owner: "local", repo: File.basename(released_dir))]
    )
    fetcher = Metanorma::Release::Platform::Local::Fetcher.new(base_path: File.dirname(released_dir))
    manifest_reader = Metanorma::Release::PlatformFactory::NullManifestReader.new
    channel_filter = Metanorma::Release::ChannelFilter.new([])
    stage_filter = Metanorma::Release::StageFilter.new([])
    routing = Metanorma::Release::ByDocument.new
    asset_processor = Metanorma::Release::AssetProcessor.new(output_dir: output_dir, routing: routing, canonicalize: true)
    delta_state = Metanorma::Release::DeltaState.new(cache_store: Metanorma::Release::FileCacheStore.new(cache_dir), output_dir: output_dir)

    deps = Metanorma::Release::AggregationPipeline::Dependencies.new(
      discoverer: discoverer, fetcher: fetcher, manifest_reader: manifest_reader,
      channel_filter: channel_filter, stage_filter: stage_filter,
      asset_processor: asset_processor, delta_state: delta_state
    )
    config = Metanorma::Release::AggregationPipeline::Config.new(
      organizations: [], channels: [], topic: nil,
      concurrency: 1, include_drafts: false, fail_on_error: false
    )

    Metanorma::Release::AggregationPipeline.new(deps).run(config, output_dir)
  end

  it "processes all releases on first run" do
    output1 = Dir.mktmpdir
    begin
      result1 = run_aggregation(output1, cache_dir, released_dir)
      expect(result1.documents.length).to eq(2)
    ensure
      FileUtils.rm_rf(output1)
    end
  end

  it "still returns same document count on second run" do
    output1 = Dir.mktmpdir
    output2 = Dir.mktmpdir
    begin
      run_aggregation(output1, cache_dir, released_dir)
      result2 = run_aggregation(output2, cache_dir, released_dir)
      expect(result2.documents.length).to eq(2)
    ensure
      FileUtils.rm_rf(output1)
      FileUtils.rm_rf(output2)
    end
  end
end
