# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "shared_contexts"

RSpec.describe "Channel filtering", type: :integration do
  include_context "with released documents"

  def run_aggregation(channels:, output_dir:, released_dir:)
    discoverer = Metanorma::Release::Platform::StaticDiscoverer.new(
      repos: [Metanorma::Release::RepoRef.new(owner: "local",
                                              repo: File.basename(released_dir))],
    )
    fetcher = Metanorma::Release::Platform::Local::Fetcher.new(base_path: File.dirname(released_dir))
    manifest_reader = Metanorma::Release::Platform::Null::ManifestReader.new
    metadata_filter = Metanorma::Release::MetadataFilter.new(channels: channels)
    routing = Metanorma::Release::ByDocument.new
    asset_processor = Metanorma::Release::AssetProcessor.new(output_dir: output_dir, routing: routing,
                                                             canonicalize: true)
    delta_state = Metanorma::Release::NullDeltaState.new

    deps = Metanorma::Release::AggregationPipeline::Dependencies.new(
      discoverer: discoverer, fetcher: fetcher, manifest_reader: manifest_reader,
      metadata_filter: metadata_filter,
      asset_processor: asset_processor, delta_state: delta_state
    )
    config = Metanorma::Release::AggregationPipeline::Config.new(
      organizations: [], channels: channels, topic: nil,
      concurrency: 1, include_drafts: false, fail_on_error: false
    )
    Metanorma::Release::AggregationPipeline.new(deps).run(config, output_dir)
  end

  it "includes documents matching the channel filter" do
    output_dir = Dir.mktmpdir
    begin
      result = run_aggregation(
        channels: ["public"],
        output_dir: output_dir,
        released_dir: released_dir,
      )
      filter = Metanorma::Release::Channel.new("public")
      result.publications.each do |doc|
        expect(doc.channels.any? do |c|
          filter.eql?(Metanorma::Release::Channel.new(c)) || c.start_with?("#{filter.name}/")
        end).to be true
      end
    ensure
      FileUtils.rm_rf(output_dir)
    end
  end

  it "includes all documents when no filter specified" do
    output_dir = Dir.mktmpdir
    begin
      result = run_aggregation(channels: [], output_dir: output_dir,
                               released_dir: released_dir)
      expect(result.publications.length).to be > 0
    ensure
      FileUtils.rm_rf(output_dir)
    end
  end

  it "excludes documents not matching the filter" do
    output_dir = Dir.mktmpdir
    begin
      result = run_aggregation(
        channels: ["internal"],
        output_dir: output_dir,
        released_dir: released_dir,
      )
      expect(result.publications).to be_empty
    ensure
      FileUtils.rm_rf(output_dir)
    end
  end
end
