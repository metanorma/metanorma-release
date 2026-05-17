# frozen_string_literal: true

require "tmpdir"

RSpec.describe Metanorma::Release::FileCacheStore do
  let(:tmpdir) { Dir.mktmpdir }
  let(:store) { described_class.new(tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  it "round-trips set and get" do
    store.set("key1", "value1")
    expect(store.get("key1")).to eq("value1")
  end

  it "returns nil for missing key" do
    expect(store.get("missing")).to be_nil
  end

  it "deletes a key" do
    store.set("key1", "value1")
    store.delete("key1")
    expect(store.get("key1")).to be_nil
  end

  it "clears all keys" do
    store.set("a", "1")
    store.set("b", "2")
    store.clear
    expect(store.keys).to be_empty
  end

  it "lists all stored keys" do
    store.set("alpha", "1")
    store.set("beta", "2")
    expect(store.keys.sort).to eq(%w[alpha beta])
  end

  it "sanitizes key with special characters" do
    store.set("etag:CalConnect/cc-datetime", "value")
    expect(store.get("etag:CalConnect/cc-datetime")).to eq("value")
  end

  it "persists across instances" do
    store.set("key1", "value1")
    store2 = described_class.new(tmpdir)
    expect(store2.get("key1")).to eq("value1")
  end
end

RSpec.describe Metanorma::Release::NullCacheStore do
  let(:store) { described_class.new }

  it "returns nil from get" do
    expect(store.get("anything")).to be_nil
  end

  it "set is a no-op" do
    store.set("key", "value")
    expect(store.get("key")).to be_nil
  end
end
