# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require_relative 'shared_contexts'

RSpec.describe 'Verification', type: :integration do
  include_context 'with released documents'

  def run_aggregation(output_dir:, released_dir:)
    discoverer = Metanorma::Release::PlatformFactory::StaticDiscoverer.new(
      repos: [Metanorma::Release::RepoRef.new(owner: 'local', repo: File.basename(released_dir))]
    )
    fetcher = Metanorma::Release::Platform::Local::Fetcher.new(base_path: File.dirname(released_dir))
    manifest_reader = Metanorma::Release::PlatformFactory::NullManifestReader.new
    channel_filter = Metanorma::Release::ChannelFilter.new([])
    stage_filter = Metanorma::Release::StageFilter.new([])
    routing = Metanorma::Release::ByDocument.new
    asset_processor = Metanorma::Release::AssetProcessor.new(output_dir: output_dir, routing: routing,
                                                             canonicalize: true)
    delta_state = Metanorma::Release::NullDeltaState.new

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

  it 'succeeds when document count meets minimum' do
    output_dir = Dir.mktmpdir
    begin
      result = run_aggregation(output_dir: output_dir, released_dir: released_dir)
      expect(result.documents.length).to be >= 1
    ensure
      FileUtils.rm_rf(output_dir)
    end
  end

  it 'handles empty source gracefully' do
    empty_dir = Dir.mktmpdir
    output_dir = Dir.mktmpdir
    begin
      discoverer = Metanorma::Release::PlatformFactory::StaticDiscoverer.new(repos: [])
      deps = Metanorma::Release::AggregationPipeline::Dependencies.new(
        discoverer: discoverer,
        fetcher: Metanorma::Release::Platform::Local::Fetcher.new(base_path: empty_dir),
        manifest_reader: Metanorma::Release::PlatformFactory::NullManifestReader.new,
        channel_filter: Metanorma::Release::ChannelFilter.new([]),
        stage_filter: Metanorma::Release::StageFilter.new([]),
        asset_processor: Metanorma::Release::AssetProcessor.new(output_dir: output_dir,
                                                                routing: Metanorma::Release::ByDocument.new, canonicalize: true),
        delta_state: Metanorma::Release::NullDeltaState.new
      )
      config = Metanorma::Release::AggregationPipeline::Config.new(
        organizations: [], channels: [], topic: nil,
        concurrency: 1, include_drafts: false, fail_on_error: false
      )
      result = Metanorma::Release::AggregationPipeline.new(deps).run(config, output_dir)
      expect(result.documents).to be_empty
      expect(result.repo_count).to eq(0)
    ensure
      FileUtils.rm_rf(empty_dir)
      FileUtils.rm_rf(output_dir)
    end
  end
end
