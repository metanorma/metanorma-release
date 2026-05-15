# frozen_string_literal: true

require "tmpdir"

RSpec.describe Metanorma::Release::ContentHash do
  describe ".from_hex" do
    it "stores and returns the hash" do
      h = described_class.from_hex("abc123")
      expect(h.to_s).to eq("abc123")
    end
  end

  describe ".of_content" do
    it "produces consistent hash for same input" do
      data = "hello world"
      a = described_class.of_content(data)
      b = described_class.of_content(data)
      expect(a).to eql(b)
    end

    it "produces different hash for different input" do
      a = described_class.of_content("hello")
      b = described_class.of_content("world")
      expect(a).not_to eql(b)
    end
  end

  describe ".of_file" do
    it "hashes file contents", :aggregate_failures do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.txt")
        File.write(path, "file content")
        h = described_class.of_file(path)
        expect(h.to_s).to match(/\A[0-9a-f]{64}\z/)
        expect(h).to eql(described_class.of_content("file content"))
      end
    end
  end

  describe ".of_files" do
    it "sorts paths before hashing — different order same hash" do
      Dir.mktmpdir do |dir|
        a = File.join(dir, "a.txt")
        b = File.join(dir, "b.txt")
        File.write(a, "aaa")
        File.write(b, "bbb")

        h1 = described_class.of_files([a, b])
        h2 = described_class.of_files([b, a])
        expect(h1).to eql(h2)
      end
    end

    it "produces different hash for different file contents" do
      Dir.mktmpdir do |dir|
        a = File.join(dir, "a.txt")
        File.write(a, "content1")
        h1 = described_class.of_files([a])

        File.write(a, "content2")
        h2 = described_class.of_files([a])
        expect(h1).not_to eql(h2)
      end
    end

    it "returns hash of empty string for empty files list" do
      h = described_class.of_files([])
      expect(h).to eql(described_class.of_content(""))
    end
  end

  describe "equality" do
    it "same hex is equal" do
      a = described_class.from_hex("abc")
      b = described_class.from_hex("abc")
      expect(a).to eql(b)
    end

    it "different hex is not equal" do
      a = described_class.from_hex("abc")
      b = described_class.from_hex("def")
      expect(a).not_to eql(b)
    end

    it "equal objects have same hash code" do
      a = described_class.from_hex("abc")
      b = described_class.from_hex("abc")
      expect(a.hash).to eq(b.hash)
    end
  end

  it "is frozen" do
    expect(described_class.from_hex("abc")).to be_frozen
  end
end
