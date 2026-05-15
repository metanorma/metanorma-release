# frozen_string_literal: true

RSpec.describe Metanorma::Release::StageFilter do
  describe '#matches?' do
    it 'matches everything with empty stages' do
      filter = described_class.new([])
      expect(filter.matches?({ 'stage' => 'published' })).to be true
    end

    it 'matches exact stage' do
      filter = described_class.new(['published'])
      expect(filter.matches?({ 'stage' => 'published' })).to be true
    end

    it 'matches case-insensitively' do
      filter = described_class.new(['Published'])
      expect(filter.matches?({ 'stage' => 'published' })).to be true
    end

    it 'does not match different stage' do
      filter = described_class.new(['working-draft'])
      expect(filter.matches?({ 'stage' => 'published' })).to be false
    end

    it 'matches any of multiple stages' do
      filter = described_class.new(%w[published working-draft])
      expect(filter.matches?({ 'stage' => 'working-draft' })).to be true
    end
  end
end
