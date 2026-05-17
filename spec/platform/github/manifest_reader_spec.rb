# frozen_string_literal: true

require_relative "../../../lib/metanorma/release/platform/github"

RSpec.describe Metanorma::Release::Platform::GitHub::ManifestReader do
  let(:repo) { Metanorma::Release::RepoRef.new(owner: "CC", repo: "test-repo") }

  it "returns channel list when manifest found" do
    yaml = "---\ndefaults: \nchannels:\n- public/standards\n"
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
