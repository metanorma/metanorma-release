# frozen_string_literal: true

require_relative "../../../lib/metanorma/release/platform/github"

RSpec.describe Metanorma::Release::Platform::GitHub::ManifestReader do
  let(:repo) { Metanorma::Release::RepoRef.new(owner: "CC", repo: "test-repo") }

  it "returns channel list when top-level channels found" do
    yaml = "---\nchannels:\n- public/standards\n"
    client = Metanorma::Release::FakeGitHubClient.new(
      contents: { "metanorma.release.yml" => yaml },
    )
    reader = described_class.new(client: client)
    result = reader.read(repo)
    expect(result).to eq(["public/standards"])
  end

  it "extracts channels from documents entries" do
    yaml = <<~YAML
      documents:
        - pattern: "cc-s-*"
          channels: [public/standards]
        - pattern: "cc-r-*"
          channels: [public/reports]
    YAML
    client = Metanorma::Release::FakeGitHubClient.new(
      contents: { "metanorma.release.yml" => yaml },
    )
    reader = described_class.new(client: client)
    result = reader.read(repo)
    expect(result).to contain_exactly("public/standards", "public/reports")
  end

  it "combines top-level and document-level channels" do
    yaml = <<~YAML
      channels:
        - members/drafts
      documents:
        - pattern: "cc-*"
          channels: [public/standards]
    YAML
    client = Metanorma::Release::FakeGitHubClient.new(
      contents: { "metanorma.release.yml" => yaml },
    )
    reader = described_class.new(client: client)
    result = reader.read(repo)
    expect(result).to contain_exactly("members/drafts", "public/standards")
  end

  it "deduplicates channels" do
    yaml = <<~YAML
      documents:
        - pattern: "cc-a-*"
          channels: [public/standards]
        - pattern: "cc-b-*"
          channels: [public/standards]
    YAML
    client = Metanorma::Release::FakeGitHubClient.new(
      contents: { "metanorma.release.yml" => yaml },
    )
    reader = described_class.new(client: client)
    result = reader.read(repo)
    expect(result).to eq(["public/standards"])
  end

  it "returns nil when manifest not found" do
    client = Metanorma::Release::FakeGitHubClient.new(contents: {})
    reader = described_class.new(client: client)
    expect(reader.read(repo)).to be_nil
  end
end
