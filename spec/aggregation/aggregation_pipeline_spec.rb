# frozen_string_literal: true

RSpec.describe Metanorma::Release::AggregationPipeline do
  let(:mock_release_class) do
    Struct.new(:tag_name, :body, :prerelease, :draft, :html_url, :published_at, :assets, keyword_init: true)
  end

  let(:mock_asset_class) do
    Struct.new(:name, :browser_download_url, :size, :data, keyword_init: true)
  end

  let(:sample_metadata_json) do
    {
      'version' => 1, 'id' => 'cc-18011', 'title' => 'Test Doc',
      'edition' => '1', 'stage' => 'published', 'doctype' => 'standard',
      'formats' => %w[html pdf], 'channels' => ['public/standards'],
      'flavor' => 'cc', 'sourcePath' => 'sources/cc-18011.adoc'
    }
  end

  def build_release(tag: 'cc-18011/ed1', stage: 'published', channels: ['public/standards'])
    meta = sample_metadata_json.merge('stage' => stage, 'channels' => channels)
    body = "content-hash:abc123\n<!-- mn-release-metadata\n#{JSON.generate(meta)}\n-->"
    mock_release_class.new(
      tag_name: tag, body: body, prerelease: false, draft: false,
      html_url: 'https://example.com/release', published_at: '2026-05-14T00:00:00Z',
      assets: [mock_asset_class.new(name: 'cc-18011-ed1.zip', browser_download_url: 'https://example.com/asset.zip', size: 1024, data: 'zip-data')]
    )
  end

  def mock_discoverer(repos)
    Struct.new(:repos) do
      include Metanorma::Release::RepoDiscoverer
      def discover = repos
    end.new(repos)
  end

  def mock_fetcher(releases_by_repo)
    Struct.new(:releases_by_repo) do
      include Metanorma::Release::ReleaseFetcher
      def fetch(repo, etag: nil)
        releases = releases_by_repo[repo.to_s] || []
        Metanorma::Release::FetchResult.new(releases: releases, etag: "etag-#{repo}", unchanged?: false)
      end
    end.new(releases_by_repo)
  end

  let(:mock_manifest_reader) do
    Struct.new(:channels) do
      include Metanorma::Release::ManifestReader
      def read(_repo) = channels
    end.new(nil)
  end

  let(:mock_asset_processor) do
    Struct.new(:results) do
      include Metanorma::Release::Packager
      def process(_zip_data, metadata)
        Metanorma::Release::AssetProcessor::ProcessResult.new(
          files: [Metanorma::Release::DocumentFile.new(name: "#{metadata['id']}.html",
                                                       path: "#{metadata['id']}/#{metadata['id']}.html")],
          channels: metadata['channels']
        )
      end
    end.new([])
  end

  def build_deps(discoverer: mock_discoverer([]), fetcher: mock_fetcher({}),
                 manifest_reader: mock_manifest_reader,
                 channel_filter: Metanorma::Release::ChannelFilter.new([]),
                 stage_filter: Metanorma::Release::StageFilter.new([]),
                 asset_processor: mock_asset_processor,
                 delta_state: Metanorma::Release::NullDeltaState.new)
    described_class::Dependencies.new(
      discoverer: discoverer, fetcher: fetcher,
      manifest_reader: manifest_reader,
      channel_filter: channel_filter, stage_filter: stage_filter,
      asset_processor: asset_processor, delta_state: delta_state
    )
  end

  def build_config(**overrides)
    defaults = { organizations: [], channels: [], topic: 'test',
                 concurrency: 1, include_drafts: false, fail_on_error: false }
    described_class::Config.new(defaults.merge(overrides))
  end

  describe 'happy path' do
    it 'aggregates documents from repos' do
      repos = [Metanorma::Release::RepoRef.new(owner: 'CC', repo: 'test-repo')]
      releases = { 'CC/test-repo' => [build_release] }

      result = described_class.new(build_deps(
                                     discoverer: mock_discoverer(repos),
                                     fetcher: mock_fetcher(releases)
                                   )).run(build_config, '/tmp/out')

      expect(result.documents.length).to eq(1)
      expect(result.documents.first.id).to eq('cc-18011')
      expect(result.repo_count).to eq(1)
    end
  end

  describe 'empty input' do
    it 'returns empty result for no repos' do
      result = described_class.new(build_deps).run(build_config, '/tmp/out')
      expect(result.documents).to be_empty
      expect(result.repo_count).to eq(0)
    end
  end

  describe 'error handling' do
    it 'collects failed repos when fail_on_error is false' do
      repos = [Metanorma::Release::RepoRef.new(owner: 'CC', repo: 'test-repo')]
      failing_fetcher = Struct.new(:repos) do
        include Metanorma::Release::ReleaseFetcher
        def fetch(_repo, etag: nil)
          raise 'Network error'
        end
      end.new(repos)

      result = described_class.new(build_deps(
                                     discoverer: mock_discoverer(repos),
                                     fetcher: failing_fetcher
                                   )).run(build_config(fail_on_error: false), '/tmp/out')

      expect(result.failed_repos.length).to eq(1)
      expect(result.failed_repos.first.tag).to eq('CC/test-repo')
    end

    it 'raises on failure when fail_on_error is true' do
      repos = [Metanorma::Release::RepoRef.new(owner: 'CC', repo: 'test-repo')]
      failing_fetcher = Struct.new(:repos) do
        include Metanorma::Release::ReleaseFetcher
        def fetch(_repo, etag: nil)
          raise 'Network error'
        end
      end.new(repos)

      expect do
        described_class.new(build_deps(
                              discoverer: mock_discoverer(repos),
                              fetcher: failing_fetcher
                            )).run(build_config(fail_on_error: true), '/tmp/out')
      end.to raise_error('Network error')
    end
  end

  describe 'channel filtering' do
    it 'excludes documents not matching channel filter' do
      repos = [Metanorma::Release::RepoRef.new(owner: 'CC', repo: 'test-repo')]
      releases = { 'CC/test-repo' => [build_release(channels: ['internal/secrets'])] }

      filter = Metanorma::Release::ChannelFilter.new(['public/standards'])
      result = described_class.new(build_deps(
                                     discoverer: mock_discoverer(repos),
                                     fetcher: mock_fetcher(releases),
                                     channel_filter: filter
                                   )).run(build_config, '/tmp/out')

      expect(result.documents.length).to eq(0)
    end
  end

  describe 'stage filtering' do
    it 'excludes documents not matching stage filter' do
      repos = [Metanorma::Release::RepoRef.new(owner: 'CC', repo: 'test-repo')]
      releases = { 'CC/test-repo' => [build_release(stage: 'working-draft')] }

      filter = Metanorma::Release::StageFilter.new(['published'])
      result = described_class.new(build_deps(
                                     discoverer: mock_discoverer(repos),
                                     fetcher: mock_fetcher(releases),
                                     stage_filter: filter
                                   )).run(build_config, '/tmp/out')

      expect(result.documents.length).to eq(0)
    end
  end

  describe 'draft filtering' do
    it 'excludes prerelease when include_drafts is false' do
      repos = [Metanorma::Release::RepoRef.new(owner: 'CC', repo: 'test-repo')]
      release = mock_release_class.new(
        tag_name: 'cc-18011/ed1-wd', body: 'no metadata', prerelease: true,
        draft: false, html_url: 'https://example.com', published_at: '2026-01-01',
        assets: [mock_asset_class.new(name: 'test.zip', browser_download_url: 'https://example.com', size: 100, data: 'zip')]
      )

      releases = { 'CC/test-repo' => [release] }
      result = described_class.new(build_deps(
                                     discoverer: mock_discoverer(repos),
                                     fetcher: mock_fetcher(releases)
                                   )).run(build_config(include_drafts: false), '/tmp/out')

      expect(result.documents.length).to eq(0)
    end
  end

  describe 'manifest reader' do
    it "skips repos whose manifest channels don't overlap with filter" do
      repos = [Metanorma::Release::RepoRef.new(owner: 'CC', repo: 'test-repo')]
      reader = Struct.new(:ch) do
        include Metanorma::Release::ManifestReader
        def read(_repo) = ch
      end.new(['internal/secrets'])

      filter = Metanorma::Release::ChannelFilter.new(['public/standards'])
      releases = { 'CC/test-repo' => [build_release] }

      result = described_class.new(build_deps(
                                     discoverer: mock_discoverer(repos),
                                     fetcher: mock_fetcher(releases),
                                     manifest_reader: reader,
                                     channel_filter: filter
                                   )).run(build_config, '/tmp/out')

      expect(result.documents.length).to eq(0)
    end
  end
end
