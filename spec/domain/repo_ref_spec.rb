# frozen_string_literal: true

RSpec.describe Metanorma::Release::RepoRef do
  let(:ref) { described_class.new(owner: 'CalConnect', repo: 'cc-datetime-explicit') }

  describe '#to_s' do
    it 'formats as owner/repo' do
      expect(ref.to_s).to eq('CalConnect/cc-datetime-explicit')
    end
  end

  describe 'equality' do
    it 'same owner/repo is equal' do
      a = described_class.new(owner: 'CalConnect', repo: 'cc-datetime-explicit')
      b = described_class.new(owner: 'CalConnect', repo: 'cc-datetime-explicit')
      expect(a).to eql(b)
    end

    it 'different owner is not equal' do
      a = described_class.new(owner: 'CalConnect', repo: 'cc-datetime-explicit')
      b = described_class.new(owner: 'ISO', repo: 'cc-datetime-explicit')
      expect(a).not_to eql(b)
    end

    it 'different repo is not equal' do
      a = described_class.new(owner: 'CalConnect', repo: 'cc-datetime-explicit')
      b = described_class.new(owner: 'CalConnect', repo: 'cc-other')
      expect(a).not_to eql(b)
    end

    it 'equal objects have same hash' do
      a = described_class.new(owner: 'CalConnect', repo: 'cc-datetime-explicit')
      b = described_class.new(owner: 'CalConnect', repo: 'cc-datetime-explicit')
      expect(a.hash).to eq(b.hash)
    end
  end

  it 'is frozen' do
    expect(ref).to be_frozen
  end
end
