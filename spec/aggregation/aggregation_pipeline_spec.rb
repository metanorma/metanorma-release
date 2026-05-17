# frozen_string_literal: true

require "json"

class TestRelease
  attr_reader :tag_name, :body, :prerelease, :draft, :html_url, :published_at,
              :assets

  def initialize(tag_name:, body:, prerelease:, draft:, html_url:,
published_at:, assets:)
    @tag_name = tag_name
    @body = body
    @prerelease = prerelease
    @draft = draft
    @html_url = html_url
    @published_at = published_at
    @assets = assets
  end
end

class TestAsset
  attr_reader :name, :data

  def initialize(name:, data:)
    @name = name
    @data = data
  end
end

class TestDiscoverer
  include Metanorma::Release::RepoDiscoverer

  def initialize(repos)
    @repos = repos
  end

  def discover
    @repos
  end
end

class TestFetcher
  include Metanorma::Release::ReleaseFetcher

  def initialize(releases_by_repo)
    @releases_by_repo = releases_by_repo
  end

  def fetch(repo, etag: nil)
    releases = @releases_by_repo[repo.to_s] || []
    Metanorma::Release::FetchResult.new(releases: releases,
                                        etag: "etag-#{repo}", unchanged?: false)
  end
end

class TestManifestReader
  include Metanorma::Release::ManifestReader

  def read(_repo)
    nil
  end
end

class TestAssetProcessor
  def process(_zip_data, metadata)
    Metanorma::Release::AssetProcessor::ProcessResult.new(
      files: [Metanorma::Release::PublicationFile.new(
        format: "html", name: "#{metadata['id']}.html",
        path: "#{metadata['id']}/#{metadata['id']}.html"
      )],
      channels: metadata["channels"],
    )
  end
end

RSpec.describe Metanorma::Release::AggregationPipeline do
  def sample_metadata_json
    {
      "version" => 1, "id" => "cc-18011", "identifier" => "CC 18011:2018",
      "title" => "Test Doc",
      "edition" => "1", "stage" => "60", "doctype" => "standard",
      "formats" => %w[html pdf], "channels" => ["public"],
      "publisher" => "cc", "sourcePath" => "sources/cc-18011.adoc"
    }
  end

  def build_release(tag: "cc-18011/ed1", stage: "60", channels: ["public"])
    meta = sample_metadata_json.merge("stage" => stage, "channels" => channels)
    body = "content-hash:abc123\n<!-- mn-release-metadata\n#{JSON.generate(meta)}\n-->"
    TestRelease.new(
      tag_name: tag, body: body, prerelease: false, draft: false,
      html_url: "https://example.com/release", published_at: "2026-05-14T00:00:00Z",
      assets: [TestAsset.new(name: "cc-18011-ed1.zip", data: "zip-data")]
    )
  end

  describe "happy path" do
    it "aggregates publications from repos" do
      repos = [Metanorma::Release::RepoRef.new(owner: "CC", repo: "test-repo")]
      releases = { "CC/test-repo" => [build_release] }

      deps = described_class::Dependencies.new(
        discoverer: TestDiscoverer.new(repos),
        fetcher: TestFetcher.new(releases),
        manifest_reader: TestManifestReader.new,
        metadata_filter: Metanorma::Release::MetadataFilter.new,
        asset_processor: TestAssetProcessor.new,
        delta_state: Metanorma::Release::NullDeltaState.new,
      )

      config = described_class::Config.new(
        organizations: ["CC"], channels: [], topic: "test",
        concurrency: 1, include_drafts: true, fail_on_error: false
      )

      result = described_class.new(deps).run(config, "/tmp/out")
      expect(result.publications.length).to eq(1)
      expect(result.publications.first.slug).to eq("cc-18011-2018")
      expect(result.repo_count).to eq(1)
    end
  end

  describe "empty input" do
    it "returns empty result for no repos" do
      deps = described_class::Dependencies.new(
        discoverer: TestDiscoverer.new([]),
        fetcher: TestFetcher.new({}),
        manifest_reader: TestManifestReader.new,
        metadata_filter: Metanorma::Release::MetadataFilter.new,
        asset_processor: TestAssetProcessor.new,
        delta_state: Metanorma::Release::NullDeltaState.new,
      )

      config = described_class::Config.new(
        organizations: [], channels: [], topic: "test",
        concurrency: 1, include_drafts: false, fail_on_error: false
      )

      result = described_class.new(deps).run(config, "/tmp/out")
      expect(result.publications).to be_empty
      expect(result.repo_count).to eq(0)
    end
  end
end
