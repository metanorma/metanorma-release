# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Metanorma::Release::PlatformFactory do
  describe ".build_publisher" do
    it "builds NullPublisher for 'null' platform" do
      publisher = described_class.build_publisher("null", {})
      expect(publisher).to be_a(Metanorma::Release::Platform::Null::Publisher)
    end

    it "builds Local::Publisher for 'local' platform" do
      tmpdir = Dir.mktmpdir
      begin
        publisher = described_class.build_publisher("local",
                                                    { output_dir: tmpdir })
        expect(publisher).to be_a(Metanorma::Release::Platform::Local::Publisher)
      ensure
        FileUtils.rm_rf(tmpdir)
      end
    end

    it "raises ArgumentError for unknown platform" do
      expect do
        described_class.build_publisher("unknown", {})
      end.to raise_error(ArgumentError)
    end
  end

  describe ".build_aggregation_adapters" do
    it "builds local adapters for local: path source" do
      tmpdir = Dir.mktmpdir
      begin
        adapters = described_class.build_aggregation_adapters(
          source: "local:#{tmpdir}", organizations: [], topic: nil,
          repos: nil, token: nil
        )
        expect(adapters[:discoverer]).to be_a(Metanorma::Release::Platform::Local::DirectoryDiscoverer)
        expect(adapters[:fetcher]).to be_a(Metanorma::Release::Platform::Local::Fetcher)
        expect(adapters[:manifest_reader]).to be_a(Metanorma::Release::Platform::Null::ManifestReader)
      ensure
        FileUtils.rm_rf(tmpdir)
      end
    end
  end
end

RSpec.describe Metanorma::Release::Platform::StaticDiscoverer do
  it "returns configured repos" do
    repos = [Metanorma::Release::RepoRef.new(owner: "local", repo: "test")]
    discoverer = described_class.new(repos: repos)
    expect(discoverer.discover).to eq(repos)
  end
end

RSpec.describe Metanorma::Release::Platform::Null::ManifestReader do
  it "returns nil" do
    reader = described_class.new
    repo = Metanorma::Release::RepoRef.new(owner: "test", repo: "repo")
    expect(reader.read(repo)).to be_nil
  end
end
