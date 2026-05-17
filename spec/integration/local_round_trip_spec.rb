# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require "zip"
require_relative "shared_contexts"

RSpec.describe "Local round-trip: package → aggregate → index",
               type: :integration do
  include_context "with compiled documents"

  let(:package_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(package_dir) }

  it "produces a valid index from locally packaged documents" do
    # Phase 1: Package compiled documents using ReleasePipeline
    change_detector = Metanorma::Release::ContentHashChangeDetector.new(previous_releases: {})
    packager = Metanorma::Release::ZipPackager.new(output_dir: compiled_dir)
    publisher = Metanorma::Release::Platform::Local::Publisher.new(output_dir: package_dir)
    slug_registry = Metanorma::Release::SlugRegistry.default

    deps = Metanorma::Release::ReleasePipeline::Dependencies.new(
      extractor: Metanorma::Release::Publication, filters: [], change_detector: change_detector,
      packager: packager, publisher: publisher, slug_registry: slug_registry,
      manifest: nil, channel_override: nil
    )
    config = Metanorma::Release::ReleasePipeline::Config.new(
      output_dir: compiled_dir, manifest_path: nil,
      force: false, force_replace_patterns: nil, concurrency: 1, default_visibility: "public"
    )

    release_result = Metanorma::Release::ReleasePipeline.new(deps).run(config)
    expect(release_result.released.length).to eq(2)

    # Verify packages on disk
    expect(Dir.glob(File.join(package_dir, "*.zip")).length).to eq(2)
    expect(Dir.glob(File.join(package_dir, "*.meta.json")).length).to eq(2)

    # Phase 2: Aggregate from local packages
    base_path = File.dirname(package_dir)
    repo_name = File.basename(package_dir)
    discoverer = Metanorma::Release::PlatformFactory::StaticDiscoverer.new(repos: [Metanorma::Release::RepoRef.new(
      owner: "local", repo: repo_name,
    )])
    fetcher = Metanorma::Release::Platform::Local::Fetcher.new(base_path: base_path)
    manifest_reader = Metanorma::Release::PlatformFactory::NullManifestReader.new
    metadata_filter = Metanorma::Release::MetadataFilter.new
    routing = Metanorma::Release::ByDocument.new
    asset_processor = Metanorma::Release::AssetProcessor.new(output_dir: output_dir, routing: routing,
                                                             canonicalize: true)
    delta_state = Metanorma::Release::NullDeltaState.new

    agg_deps = Metanorma::Release::AggregationPipeline::Dependencies.new(
      discoverer: discoverer, fetcher: fetcher, manifest_reader: manifest_reader,
      metadata_filter: metadata_filter,
      asset_processor: asset_processor, delta_state: delta_state
    )
    agg_config = Metanorma::Release::AggregationPipeline::Config.new(
      organizations: [], channels: [], topic: nil,
      concurrency: 1, include_drafts: false, fail_on_error: false
    )

    agg_result = Metanorma::Release::AggregationPipeline.new(agg_deps).run(
      agg_config, output_dir
    )
    expect(agg_result.publications.length).to eq(2)

    # Verify metadata survived the round-trip
    doc = agg_result.publications.find { |d| d.slug.include?("cc-18011") }
    expect(doc).not_to be_nil
    expect(doc.title).not_to be_empty
    expect(doc.edition).to eq("1")
    expect(doc.files.length).to be > 0

    # Verify files on disk
    doc.files.each do |file|
      expect(File.exist?(File.join(output_dir, file.path))).to be true
    end
  end
end
