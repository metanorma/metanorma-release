# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require "zip"
require_relative "shared_contexts"

RSpec.describe "Release → Publish → Aggregate round-trip", type: :integration do
  include_context "with compiled documents"

  it "round-trips metadata through publish and aggregate" do
    # Phase 1: Extract + package with local publisher
    package_dir = Dir.mktmpdir
    begin
      extractor = Metanorma::Release::RxlExtractor.new
      change_detector = Metanorma::Release::ContentHashChangeDetector.new(previous_releases: {})
      packager = Metanorma::Release::ZipPackager.new
      publisher = Metanorma::Release::Platform::Local::Publisher.new(output_dir: package_dir)
      naming = Metanorma::Release::NamingRegistry.default_registry

      deps = Metanorma::Release::ReleasePipeline::Dependencies.new(
        extractor: extractor, filters: [], change_detector: change_detector,
        packager: packager, publisher: publisher, naming_registry: naming,
        manifest: nil, channel_override: nil
      )
      config = Metanorma::Release::ReleasePipeline::Config.new(
        output_dir: compiled_dir, manifest_path: nil,
        force: false, force_replace_patterns: nil, concurrency: 1, default_visibility: "public"
      )

      release_result = Metanorma::Release::ReleasePipeline.new(deps).run(config)
      expect(release_result.released.length).to be > 0

      # Verify released artifacts have valid metadata
      release_result.released_artifacts.each do |artifact|
        expect(artifact.id).to match(/cc-\d+/)
        expect(artifact.url).to start_with("file://")
      end

      # Phase 2: Aggregate from the local packages
      base_path = File.dirname(package_dir)
      repo_name = File.basename(package_dir)

      output_dir = Dir.mktmpdir
      begin
        discoverer = Metanorma::Release::PlatformFactory::StaticDiscoverer.new(repos: [Metanorma::Release::RepoRef.new(owner: "local", repo: repo_name)])
        fetcher = Metanorma::Release::Platform::Local::Fetcher.new(base_path: base_path)
        manifest_reader = Metanorma::Release::PlatformFactory::NullManifestReader.new
        channel_filter = Metanorma::Release::ChannelFilter.new([])
        stage_filter = Metanorma::Release::StageFilter.new([])
        routing = Metanorma::Release::ByDocument.new
        asset_processor = Metanorma::Release::AssetProcessor.new(output_dir: output_dir, routing: routing, canonicalize: true)
        delta_state = Metanorma::Release::NullDeltaState.new

        agg_deps = Metanorma::Release::AggregationPipeline::Dependencies.new(
          discoverer: discoverer, fetcher: fetcher, manifest_reader: manifest_reader,
          channel_filter: channel_filter, stage_filter: stage_filter,
          asset_processor: asset_processor, delta_state: delta_state
        )
        agg_config = Metanorma::Release::AggregationPipeline::Config.new(
          organizations: [], channels: [], topic: nil,
          concurrency: 1, include_drafts: false, fail_on_error: false
        )

        agg_result = Metanorma::Release::AggregationPipeline.new(agg_deps).run(agg_config, output_dir)

        # Verify metadata survived the round-trip
        agg_result.documents.each do |doc|
          expect(doc.title).not_to be_empty
          expect(doc.stage).not_to be_empty
          expect(doc.id).to match(/cc-\d+/)
        end
      ensure
        FileUtils.rm_rf(output_dir)
      end
    ensure
      FileUtils.rm_rf(package_dir)
    end
  end
end
