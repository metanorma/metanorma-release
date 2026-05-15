# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe Metanorma::Release::Platform::Local::DirectoryDiscoverer do
  let(:tmpdir) { Dir.mktmpdir }
  after { FileUtils.rm_rf(tmpdir) }

  it 'scans directory for subdirectories' do
    Dir.mkdir(File.join(tmpdir, 'repo-a'))
    Dir.mkdir(File.join(tmpdir, 'repo-b'))

    discoverer = described_class.new(base_path: tmpdir)
    repos = discoverer.discover
    expect(repos.length).to eq(2)
    expect(repos.map(&:repo)).to contain_exactly('repo-a', 'repo-b')
  end

  it 'sets owner to local' do
    Dir.mkdir(File.join(tmpdir, 'my-repo'))

    discoverer = described_class.new(base_path: tmpdir)
    repos = discoverer.discover
    expect(repos.first.owner).to eq('local')
  end

  it 'returns empty array for empty directory' do
    discoverer = described_class.new(base_path: tmpdir)
    expect(discoverer.discover).to eq([])
  end

  it 'returns empty array for non-existent directory' do
    discoverer = described_class.new(base_path: '/nonexistent/path')
    expect(discoverer.discover).to eq([])
  end

  it 'ignores files and only returns directories' do
    Dir.mkdir(File.join(tmpdir, 'dir-repo'))
    File.write(File.join(tmpdir, 'some-file.txt'), 'data')

    discoverer = described_class.new(base_path: tmpdir)
    repos = discoverer.discover
    expect(repos.length).to eq(1)
    expect(repos.first.repo).to eq('dir-repo')
  end
end
