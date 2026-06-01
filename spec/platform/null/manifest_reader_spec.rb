# frozen_string_literal: true

RSpec.describe Metanorma::Release::Platform::Null::ManifestReader do
  it "returns nil for any repo" do
    repo = Metanorma::Release::RepoRef.new(owner: "org", repo: "repo")
    reader = described_class.new
    expect(reader.read(repo)).to be_nil
  end
end
