# frozen_string_literal: true

require_relative "../../../lib/metanorma/release/platform/github"

RSpec.describe Metanorma::Release::Platform::GitHub::Publisher do
  let(:tag) { "cc-18011/ed1" }
  let(:artifact) do
    Metanorma::Release::Artifact.new(
      zip_path: "/tmp/test.zip", asset_name: "test.zip", size: 1024,
    )
  end
  let(:metadata) do
    Metanorma::Release::Publication.from_json('{"id":"cc-18011","title":"Test"}')
  end
  let(:channels) { [Metanorma::Release::Channel.new("public")] }

  it "creates new release" do
    client = Metanorma::Release::FakeGitHubClient.new(releases: [])
    publisher = described_class.new(client: client, repo: "CC/test-repo")

    result = publisher.publish(tag, artifact, metadata, channels: channels)
    expect(result).to be_created
    expect(result.url).to include("github.com")
  end

  it "updates existing release" do
    existing = {
      "tag_name" => "cc-18011/ed1", "url" => "api-url",
      "html_url" => "https://github.com/test"
    }
    client = Metanorma::Release::FakeGitHubClient.new(releases: [existing])
    publisher = described_class.new(client: client, repo: "CC/test-repo")

    result = publisher.publish(tag, artifact, metadata, channels: channels)
    expect(result).not_to be_created
  end

  it "deletes existing on force_replace" do
    existing = {
      "tag_name" => "cc-18011/ed1", "url" => "api-url",
      "html_url" => "https://github.com/test"
    }
    client = Metanorma::Release::FakeGitHubClient.new(releases: [existing])
    publisher = described_class.new(client: client, repo: "CC/test-repo")

    result = publisher.publish(tag, artifact, metadata, channels: channels,
                                                        force_replace: true)
    expect(result).to be_created
  end
end
