# frozen_string_literal: true

require_relative "../../../lib/metanorma/release/platform/github"

RSpec.describe Metanorma::Release::Platform::GitHub::ManifestReader do
  let(:mock_client) { double("Octokit::Client") }
  let(:repo) { Metanorma::Release::RepoRef.new(owner: "CC", repo: "test-repo") }

  it "returns channel list when manifest found" do
    yaml = "---\ndefaults: \nchannels:\n- public/standards\n"
    # Pre-encoded Base64 of the YAML above
    encoded = [yaml].pack("m0")
    allow(mock_client).to receive(:contents).and_return({ "content" => encoded })
    reader = described_class.new(client: mock_client)
    result = reader.read(repo)
    expect(result).to eq(["public/standards"])
  end

  it "returns nil when manifest not found" do
    allow(mock_client).to receive(:contents).and_raise(StandardError)
    reader = described_class.new(client: mock_client)
    expect(reader.read(repo)).to be_nil
  end
end
