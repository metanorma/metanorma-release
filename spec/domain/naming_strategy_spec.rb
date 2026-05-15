# frozen_string_literal: true

RSpec.shared_examples 'a naming strategy' do |id:, edition:, stage:, expected_tag:, expected_asset:, expected_canonical:|
  let(:strategy) { described_class.new }
  let(:doc_id) { Metanorma::Release::DocumentId.from_raw(id) }
  let(:stage_obj) { Metanorma::Release::DocumentStage.from_status(stage) }
  let(:version) { Metanorma::Release::DocumentVersion.from(edition, stage_obj) }

  it 'computes the correct tag' do
    tag = strategy.compute_tag(doc_id.to_s, version)
    expect(tag.to_s).to eq(expected_tag)
  end

  it 'computes the correct asset name' do
    expect(strategy.compute_asset_name(doc_id.to_s, version)).to eq(expected_asset)
  end

  it 'computes the correct canonical base' do
    expect(strategy.compute_canonical_base(doc_id.to_s, version)).to eq(expected_canonical)
  end
end

RSpec.describe Metanorma::Release::EditionNaming do
  it_behaves_like 'a naming strategy',
                  id: 'CC 18011', edition: '1', stage: 'published',
                  expected_tag: 'cc-18011/ed1',
                  expected_asset: 'cc-18011-ed1.zip',
                  expected_canonical: 'cc-18011-ed1'

  it_behaves_like 'a naming strategy',
                  id: 'CC 18011', edition: '1', stage: 'working-draft',
                  expected_tag: 'cc-18011/ed1-wd',
                  expected_asset: 'cc-18011-ed1-wd.zip',
                  expected_canonical: 'cc-18011-ed1-wd'
end

RSpec.describe Metanorma::Release::VersionNaming do
  it_behaves_like 'a naming strategy',
                  id: 'S-100', edition: '5', stage: 'published',
                  expected_tag: 's-100/v5',
                  expected_asset: 's-100-v5.zip',
                  expected_canonical: 's-100-v5'
end

RSpec.describe Metanorma::Release::InternetDraftNaming do
  let(:strategy) { described_class.new }

  it 'extracts name and draft number from draft-ietf format' do
    id = 'draft-ietf-quic-34'
    version = Metanorma::Release::DocumentVersion.from('1', Metanorma::Release::DocumentStage.published)
    tag = strategy.compute_tag(id, version)
    expect(tag.to_s).to eq('id-quic/34')
    expect(tag).to be_pre_release
  end

  it 'uses fallback for non-draft-ietf ids' do
    id = 'cc-18011'
    version = Metanorma::Release::DocumentVersion.from('1', Metanorma::Release::DocumentStage.published)
    tag = strategy.compute_tag(id, version)
    expect(tag.to_s).to eq('cc-18011/draft')
  end

  it 'computes asset name as id.zip' do
    version = Metanorma::Release::DocumentVersion.from('1', Metanorma::Release::DocumentStage.published)
    expect(strategy.compute_asset_name('draft-ietf-quic-34', version)).to eq('draft-ietf-quic-34.zip')
  end
end

RSpec.describe Metanorma::Release::RfcNaming do
  it_behaves_like 'a naming strategy',
                  id: 'RFC 822', edition: '1', stage: 'published',
                  expected_tag: 'rfc-822/ed1',
                  expected_asset: 'rfc-822.zip',
                  expected_canonical: 'rfc-822-ed1'
end

RSpec.describe Metanorma::Release::DraftSuffixNaming do
  let(:strategy) { described_class.new }

  it 'extracts draft number from -dN suffix' do
    id = 'ieee-draft-std-987-6-2020-d3'
    version = Metanorma::Release::DocumentVersion.from('1', Metanorma::Release::DocumentStage.published)
    tag = strategy.compute_tag(id, version)
    expect(tag.to_s).to eq('ieee-draft-std-987-6-2020/3')
    expect(tag).to be_pre_release
  end

  it 'falls back to EditionNaming for non-draft-suffix ids' do
    id = 'ieee-std-123'
    version = Metanorma::Release::DocumentVersion.from('1', Metanorma::Release::DocumentStage.published)
    tag = strategy.compute_tag(id, version)
    expect(tag.to_s).to eq('ieee-std-123/ed1')
  end
end

RSpec.describe Metanorma::Release::NamingRegistry do
  let(:registry) { described_class.default_registry }

  it 'resolves ietf-draft to InternetDraftNaming' do
    strategy = registry.resolve(Metanorma::Release::DocumentType::IETF_DRAFT)
    expect(strategy).to be_a(Metanorma::Release::InternetDraftNaming)
  end

  it 'resolves ietf-rfc to RfcNaming' do
    strategy = registry.resolve(Metanorma::Release::DocumentType::IETF_RFC)
    expect(strategy).to be_a(Metanorma::Release::RfcNaming)
  end

  it 'resolves ieee to DraftSuffixNaming' do
    strategy = registry.resolve(Metanorma::Release::DocumentType::IEEE)
    expect(strategy).to be_a(Metanorma::Release::DraftSuffixNaming)
  end

  it 'resolves iho to VersionNaming' do
    strategy = registry.resolve(Metanorma::Release::DocumentType::IHO)
    expect(strategy).to be_a(Metanorma::Release::VersionNaming)
  end

  it 'resolves unknown type to EditionNaming default' do
    strategy = registry.resolve('unknown')
    expect(strategy).to be_a(Metanorma::Release::EditionNaming)
  end

  it 'allows custom type registration (Open/Closed)' do
    custom = Metanorma::Release::EditionNaming.new
    registry.register('custom-type', custom)
    expect(registry.resolve('custom-type')).to eq(custom)
  end
end
