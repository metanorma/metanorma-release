# frozen_string_literal: true

RSpec.describe Metanorma::Release::Release do
  it "constructs with keyword arguments" do
    r = described_class.new(
      tag_name: "v1", body: "test", prerelease: false,
      draft: false, html_url: "http://x", published_at: "2024-01-01",
      created_at: "2024-01-01", assets: []
    )
    expect(r.tag_name).to eq("v1")
    expect(r.prerelease).to be false
  end
end

RSpec.describe Metanorma::Release::Asset do
  it "constructs with keyword arguments" do
    a = described_class.new(
      name: "test.zip", browser_download_url: "http://x/test.zip",
      size: 1024, data: "PK"
    )
    expect(a.name).to eq("test.zip")
    expect(a.size).to eq(1024)
  end
end
