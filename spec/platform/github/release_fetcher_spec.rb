# frozen_string_literal: true

require_relative "../../../lib/metanorma/release/platform/github"

RSpec.describe Metanorma::Release::Platform::GitHub::ReleaseFetcher do
  let(:repo) { Metanorma::Release::RepoRef.new(owner: "CC", repo: "test-repo") }

  it "fetches releases for repo" do
    client = Metanorma::Release::FakeGitHubClient.new(
      releases: [
        { tag_name: "cc-18011/ed1", body: "test body", prerelease: false,
          draft: false, html_url: "https://github.com/test",
          published_at: "2026-01-01", created_at: "2026-01-01",
          assets: [{ name: "cc-18011-ed1.zip",
                     browser_download_url: "https://example.com/asset",
                     size: 1024 }] },
      ],
    )
    fetcher = described_class.new(client: client)
    result = fetcher.fetch(repo)
    expect(result.releases.length).to eq(1)
    expect(result.releases.first.tag_name).to eq("cc-18011/ed1")
    expect(result).not_to be_unchanged
  end

  it "returns empty for repo with no releases" do
    client = Metanorma::Release::FakeGitHubClient.new(releases: [])
    fetcher = described_class.new(client: client)
    result = fetcher.fetch(repo)
    expect(result.releases).to be_empty
  end
end
