# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'json'

RSpec.describe Metanorma::Release::Platform::Local::Fetcher do
  let(:tmpdir) { Dir.mktmpdir }
  after { FileUtils.rm_rf(tmpdir) }

  let(:repo) { Metanorma::Release::RepoRef.new(owner: 'local', repo: 'test-repo') }

  def create_release_package(dir, name, metadata)
    Dir.mkdir(File.join(tmpdir, dir)) unless Dir.exist?(File.join(tmpdir, dir))
    File.write(File.join(tmpdir, dir, "#{name}.zip"), 'PK fake zip')
    File.write(File.join(tmpdir, dir, "#{name}.meta.json"), JSON.generate(metadata))
  end

  it 'finds zip + metadata pairs in directory' do
    create_release_package('test-repo', 'cc-18011-ed1', {
                             'id' => 'cc-18011', 'title' => 'Test', 'edition' => '1', 'stage' => 'published'
                           })

    fetcher = described_class.new(base_path: tmpdir)
    result = fetcher.fetch(repo)
    expect(result.releases.length).to eq(1)
    expect(result.releases.first.tag_name).to eq('cc-18011/1')
  end

  it 'constructs releases with correct metadata' do
    create_release_package('test-repo', 'cc-18011-ed1', {
                             'id' => 'cc-18011', 'title' => 'Test Doc', 'edition' => '1', 'stage' => 'published',
                             'channels' => ['public/standards']
                           })

    fetcher = described_class.new(base_path: tmpdir)
    result = fetcher.fetch(repo)
    release = result.releases.first

    expect(release.body).to include('mn-release-metadata')
    expect(release.body).to include('cc-18011')
    expect(release.assets.first.name).to eq('cc-18011-ed1.zip')
  end

  it 'produces file:// URLs pointing to actual files' do
    create_release_package('test-repo', 'cc-18011-ed1', {
                             'id' => 'cc-18011', 'title' => 'Test', 'edition' => '1', 'stage' => 'published'
                           })

    fetcher = described_class.new(base_path: tmpdir)
    result = fetcher.fetch(repo)
    asset_url = result.releases.first.assets.first.browser_download_url

    expect(asset_url).to start_with('file://')
    expect(asset_url).to include('cc-18011-ed1.zip')
  end

  it 'skips zip with missing metadata' do
    Dir.mkdir(File.join(tmpdir, 'test-repo'))
    File.write(File.join(tmpdir, 'test-repo', 'orphan.zip'), 'PK data')

    fetcher = described_class.new(base_path: tmpdir)
    result = fetcher.fetch(repo)
    expect(result.releases).to be_empty
  end

  it 'returns empty FetchResult for empty directory' do
    Dir.mkdir(File.join(tmpdir, 'test-repo'))

    fetcher = described_class.new(base_path: tmpdir)
    result = fetcher.fetch(repo)
    expect(result.releases).to be_empty
    expect(result).not_to be_unchanged
  end

  it 'handles multiple zip packages' do
    create_release_package('test-repo', 'cc-18011-ed1', {
                             'id' => 'cc-18011', 'title' => 'Doc 1', 'edition' => '1', 'stage' => 'published'
                           })
    create_release_package('test-repo', 'cc-18012-ed1', {
                             'id' => 'cc-18012', 'title' => 'Doc 2', 'edition' => '1', 'stage' => 'published'
                           })

    fetcher = described_class.new(base_path: tmpdir)
    result = fetcher.fetch(repo)
    expect(result.releases.length).to eq(2)
  end

  it 'detects prerelease from stage' do
    create_release_package('test-repo', 'cc-18011-ed1-wd', {
                             'id' => 'cc-18011', 'title' => 'Draft', 'edition' => '1', 'stage' => 'working-draft'
                           })

    fetcher = described_class.new(base_path: tmpdir)
    result = fetcher.fetch(repo)
    expect(result.releases.first.prerelease).to be true
  end

  it 'skips release with invalid metadata JSON' do
    Dir.mkdir(File.join(tmpdir, 'test-repo'))
    File.write(File.join(tmpdir, 'test-repo', 'bad.zip'), 'PK data')
    File.write(File.join(tmpdir, 'test-repo', 'bad.meta.json'), 'not valid json{')

    fetcher = described_class.new(base_path: tmpdir)
    result = fetcher.fetch(repo)
    expect(result.releases).to be_empty
  end
end
