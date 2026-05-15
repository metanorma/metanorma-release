# frozen_string_literal: true

require "metanorma/release/platform/github"
require "ostruct"

RSpec.describe Metanorma::Release::Platform::GitHub::Publisher do
  let(:mock_client) { double("Octokit::Client") }
  let(:publisher) { described_class.new(client: mock_client, repo: "CC/test-repo") }
  let(:tag) { Metanorma::Release::ReleaseTag.create("cc-18011/ed1", pre_release: false) }
  let(:artifact) { Metanorma::Release::Artifact.new(zip_path: "/tmp/test.zip", asset_name: "test.zip", size: 1024) }
  let(:metadata) { Metanorma::Release::ReleaseMetadata.new({ "id" => "cc-18011", "title" => "Test" }) }
  let(:channels) { [Metanorma::Release::Channel.public("standards")] }

  it "creates new release" do
    allow(mock_client).to receive(:releases).and_return([])
    allow(mock_client).to receive(:create_release).and_return(
      { "html_url" => "https://github.com/test/test/releases/tag/cc-18011/ed1", "id" => 1 }
    )
    allow(mock_client).to receive(:upload_asset).and_return(true)

    result = publisher.publish(tag, artifact, metadata, channels: channels)
    expect(result).to be_created
    expect(result.url).to include("github.com")
  end

  it "updates existing release" do
    existing = { "tag_name" => "cc-18011/ed1", "url" => "api-url", "html_url" => "https://github.com/test" }
    allow(mock_client).to receive(:releases).and_return([existing])
    allow(mock_client).to receive(:update_release).and_return({})

    result = publisher.publish(tag, artifact, metadata, channels: channels)
    expect(result).not_to be_created
  end

  it "deletes existing on force_replace" do
    existing = { "tag_name" => "cc-18011/ed1", "url" => "api-url", "html_url" => "https://github.com/test" }
    allow(mock_client).to receive(:releases).and_return([existing])
    allow(mock_client).to receive(:delete_release).and_return(true)
    allow(mock_client).to receive(:delete_ref).and_return(true)
    allow(mock_client).to receive(:create_release).and_return(
      { "html_url" => "https://github.com/test/new", "id" => 2 }
    )
    allow(mock_client).to receive(:upload_asset).and_return(true)

    result = publisher.publish(tag, artifact, metadata, channels: channels, force_replace: true)
    expect(result).to be_created
  end
end
