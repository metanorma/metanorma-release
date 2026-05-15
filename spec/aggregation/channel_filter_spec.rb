# frozen_string_literal: true

RSpec.describe Metanorma::Release::ChannelFilter do
  describe '#matches?' do
    it 'matches everything with empty filter' do
      filter = described_class.new([])
      expect(filter.matches?({ 'channels' => ['public/standards'] })).to be true
    end

    it 'matches exact channel' do
      filter = described_class.new(['public/standards'])
      expect(filter.matches?({ 'channels' => ['public/standards'] })).to be true
    end

    it 'matches when any channel overlaps' do
      filter = described_class.new(['public/standards'])
      expect(filter.matches?({ 'channels' => ['public/standards', 'public/reports'] })).to be true
    end

    it 'does not match different channels' do
      filter = described_class.new(['members/drafts'])
      expect(filter.matches?({ 'channels' => ['public/standards'] })).to be false
    end

    it 'matches any of multiple filter channels' do
      filter = described_class.new(['members/drafts', 'public/standards'])
      expect(filter.matches?({ 'channels' => ['public/standards'] })).to be true
    end
  end

  describe '#overlaps?' do
    it 'returns true for empty filter' do
      filter = described_class.new([])
      expect(filter.overlaps?(['public/standards'])).to be true
    end

    it 'returns true for matching manifest' do
      filter = described_class.new(['public/standards'])
      expect(filter.overlaps?(['public/standards', 'public/reports'])).to be true
    end

    it 'returns false for non-matching manifest' do
      filter = described_class.new(['members/drafts'])
      expect(filter.overlaps?(['public/standards'])).to be false
    end
  end
end
