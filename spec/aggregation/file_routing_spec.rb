# frozen_string_literal: true

RSpec.shared_examples "a file routing strategy" do |file_name:, metadata:, expected_path:|
  let(:routing) { described_class.new }

  it "computes the correct path for #{file_name}" do
    expect(routing.compute_path(file_name, metadata)).to eq(expected_path)
  end
end

RSpec.describe Metanorma::Release::ByDocument do
  it_behaves_like "a file routing strategy",
    file_name: "cc-18011.html", metadata: { "id" => "cc-18011" },
    expected_path: "cc-18011/cc-18011.html"
end

RSpec.describe Metanorma::Release::Flat do
  it_behaves_like "a file routing strategy",
    file_name: "cc-18011.html", metadata: { "id" => "cc-18011" },
    expected_path: "cc-18011.html"
end

RSpec.describe Metanorma::Release::ByFormat do
  it_behaves_like "a file routing strategy",
    file_name: "cc-18011.html", metadata: { "id" => "cc-18011" },
    expected_path: "html/cc-18011.html"

  it_behaves_like "a file routing strategy",
    file_name: "cc-18011.pdf", metadata: { "id" => "cc-18011" },
    expected_path: "pdf/cc-18011.pdf"
end

RSpec.describe Metanorma::Release::FileRoutingFactory do
  it "resolves by-document" do
    expect(described_class.from_name("by-document")).to be_a(Metanorma::Release::ByDocument)
  end

  it "resolves flat" do
    expect(described_class.from_name("flat")).to be_a(Metanorma::Release::Flat)
  end

  it "resolves by-format" do
    expect(described_class.from_name("by-format")).to be_a(Metanorma::Release::ByFormat)
  end

  it "raises for unknown mode" do
    expect { described_class.from_name("unknown") }.to raise_error(ArgumentError)
  end
end
