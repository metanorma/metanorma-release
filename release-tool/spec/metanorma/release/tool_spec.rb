RSpec.describe Metanorma::Release::Tool do
  it "has a version number" do
    expect(Metanorma::Release::Tool::VERSION).not_to be nil
  end

  it "gems not empty for valid path" do
    expect(Metanorma::Release::Tool::gems('../../../..')).not_to be nil
  end
end
