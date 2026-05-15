# frozen_string_literal: true

require_relative "../../../lib/metanorma/release/platform/github"

RSpec.describe Metanorma::Release::Platform::GitHub::TopicDiscoverer do
  let(:mock_client) { double("Octokit::Client") }

  it "discovers repos by topic" do
    allow(mock_client).to receive(:search_repositories).and_return(
      { items: [{ name: "cc-datetime-explicit" }, { name: "cc-18011" }] }
    )
    discoverer = described_class.new(client: mock_client, organizations: ["CalConnect"], topic: "metanorma-release")
    repos = discoverer.discover
    expect(repos.length).to eq(2)
    expect(repos.first.owner).to eq("CalConnect")
  end

  it "returns empty for no results" do
    allow(mock_client).to receive(:search_repositories).and_return({ items: [] })
    discoverer = described_class.new(client: mock_client, organizations: ["CalConnect"], topic: "metanorma-release")
    expect(discoverer.discover).to be_empty
  end
end
