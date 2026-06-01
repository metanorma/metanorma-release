# frozen_string_literal: true

RSpec.describe Metanorma::Release::Platform::StaticDiscoverer do
  it "returns the provided repos" do
    repos = [
      Metanorma::Release::RepoRef.new(owner: "org", repo: "repo-a"),
      Metanorma::Release::RepoRef.new(owner: "org", repo: "repo-b"),
    ]
    discoverer = described_class.new(repos: repos)
    expect(discoverer.discover).to eq(repos)
  end

  it "returns empty list when no repos" do
    discoverer = described_class.new(repos: [])
    expect(discoverer.discover).to eq([])
  end
end
