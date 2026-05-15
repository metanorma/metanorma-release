# frozen_string_literal: true

RSpec.describe Metanorma::Release::Platform::Null::Publisher do
  let(:tag) { Metanorma::Release::ReleaseTag.create("cc-18011/ed1", pre_release: false) }
  let(:artifact) { Metanorma::Release::Artifact.new(zip_path: "/tmp/test.zip", asset_name: "test.zip", size: 100) }
  let(:metadata) { Metanorma::Release::ReleaseMetadata.new({ "id" => "cc-18011", "title" => "Test" }) }
  let(:channels) { [Metanorma::Release::Channel.public("standards")] }

  it "returns valid PublishResult" do
    publisher = described_class.new
    result = publisher.publish(tag, artifact, metadata, channels: channels)

    expect(result).to be_created
    expect(result.tag).to eq("cc-18011/ed1")
    expect(result.url).to eq("null://")
  end

  it "does not write files to disk" do
    tmpdir = Dir.mktmpdir
    begin
      before_entries = Dir.children(tmpdir)
      publisher = described_class.new
      publisher.publish(tag, artifact, metadata, channels: channels)
      after_entries = Dir.children(tmpdir)
      expect(after_entries).to eq(before_entries)
    ensure
      FileUtils.rm_rf(tmpdir)
    end
  end

  it "does not raise errors" do
    publisher = described_class.new
    expect {
      publisher.publish(tag, artifact, metadata, channels: channels, force_replace: true)
    }.not_to raise_error
  end
end
