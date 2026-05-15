# frozen_string_literal: true

RSpec.describe Metanorma::Release::ReleasePipeline do
  let(:naming_registry) { Metanorma::Release::NamingRegistry.default_registry }

  let(:mock_publisher_class) do
    Struct.new(:published) do
      include Metanorma::Release::Publisher

      def published = @published ||= []

      def publish(tag, _artifact, _metadata, channels:, force_replace: false)
        published << { tag: tag, channels: channels }
        Metanorma::Release::PublishResult.new(tag: tag, url: "mock://#{tag}", created?: true)
      end
    end
  end

  let(:mock_extractor_class) do
    Struct.new(:docs) do
      include Metanorma::Release::Extractor

      def discover(_output_dir) = docs
    end
  end

  let(:mock_change_detector_class) do
    Struct.new(:always_changed) do
      include Metanorma::Release::ChangeDetector

      def detect(_metadata, _tag, force: false)
        Metanorma::Release::ChangeResult.new(
          changed?: force || always_changed,
          current_hash: Metanorma::Release::ContentHash.from_hex('abc'),
          previous_hash: nil
        )
      end
    end
  end

  let(:mock_packager_class) do
    Struct.new(:packaged) do
      include Metanorma::Release::Packager

      def packaged = @packaged ||= []

      def package(_metadata, canonical_base:)
        result = Metanorma::Release::Artifact.new(
          zip_path: "/tmp/#{canonical_base}.zip",
          asset_name: "#{canonical_base}.zip",
          size: 1024
        )
        packaged << canonical_base
        result
      end
    end
  end

  def build_doc(id_str, edition: '1', stage: 'published')
    stage_obj = Metanorma::Release::DocumentStage.from_status(stage)
    version = Metanorma::Release::DocumentVersion.from(edition, stage_obj)
    Metanorma::Release::DocumentMetadata.new(
      id: Metanorma::Release::DocumentId.from_raw(id_str),
      title: "Test #{id_str}", version: version,
      doctype: 'standard', document_type: 'standard',
      flavor: 'cc', revdate: '2024-01-01',
      source_path: "sources/#{id_str}.adoc",
      output_dir: '/tmp/docs', formats: %w[html pdf], file_base_name: id_str
    )
  end

  describe 'happy path' do
    it 'releases changed documents and skips unchanged' do
      docs = [build_doc('cc-18011'), build_doc('cc-19060')]
      publisher = mock_publisher_class.new([])
      extractor = mock_extractor_class.new(docs)
      detector = mock_change_detector_class.new(false)
      packager = mock_packager_class.new([])

      deps = described_class::Dependencies.new(
        extractor: extractor, filters: [],
        change_detector: detector, packager: packager,
        publisher: publisher, naming_registry: naming_registry,
        manifest: nil, channel_override: nil
      )

      config = described_class::Config.new(
        output_dir: '/tmp/docs', force: true,
        force_replace_patterns: nil, concurrency: 1,
        default_visibility: 'public'
      )

      result = described_class.new(deps).run(config)
      expect(result.released.length).to eq(2)
      expect(result.skipped.length).to eq(0)
      expect(result.released_artifacts.length).to eq(2)
    end
  end

  describe 'change detection' do
    it 'skips unchanged documents' do
      docs = [build_doc('cc-18011'), build_doc('cc-19060')]
      publisher = mock_publisher_class.new([])
      extractor = mock_extractor_class.new(docs)
      detector = mock_change_detector_class.new(false)
      packager = mock_packager_class.new([])

      deps = described_class::Dependencies.new(
        extractor: extractor, filters: [],
        change_detector: detector, packager: packager,
        publisher: publisher, naming_registry: naming_registry,
        manifest: nil, channel_override: nil
      )

      config = described_class::Config.new(
        output_dir: '/tmp/docs', force: false,
        force_replace_patterns: nil, concurrency: 1,
        default_visibility: 'public'
      )

      result = described_class.new(deps).run(config)
      expect(result.skipped.length).to eq(2)
      expect(result.released.length).to eq(0)
    end
  end

  describe 'channel resolution' do
    it 'uses channel_override when set' do
      docs = [build_doc('cc-18011')]
      publisher = mock_publisher_class.new([])
      extractor = mock_extractor_class.new(docs)
      detector = mock_change_detector_class.new(false)
      packager = mock_packager_class.new([])
      override = [Metanorma::Release::Channel.members('drafts')]

      deps = described_class::Dependencies.new(
        extractor: extractor, filters: [],
        change_detector: detector, packager: packager,
        publisher: publisher, naming_registry: naming_registry,
        manifest: nil, channel_override: override
      )

      config = described_class::Config.new(
        output_dir: '/tmp/docs', force: true,
        force_replace_patterns: nil, concurrency: 1,
        default_visibility: 'public'
      )

      described_class.new(deps).run(config)
      expect(publisher.published.first[:channels]).to eq(override)
    end
  end

  describe 'error handling' do
    it 'collects individual failures' do
      docs = [build_doc('cc-18011')]
      failing_publisher = Class.new do
        include Metanorma::Release::Publisher
        def publish(*)
          raise 'Publishing failed'
        end
      end.new

      extractor = mock_extractor_class.new(docs)
      detector = mock_change_detector_class.new(false)
      packager = mock_packager_class.new([])

      deps = described_class::Dependencies.new(
        extractor: extractor, filters: [],
        change_detector: detector, packager: packager,
        publisher: failing_publisher, naming_registry: naming_registry,
        manifest: nil, channel_override: nil
      )

      config = described_class::Config.new(
        output_dir: '/tmp/docs', force: true,
        force_replace_patterns: nil, concurrency: 1,
        default_visibility: 'public'
      )

      result = described_class.new(deps).run(config)
      expect(result.failed.length).to eq(1)
      expect(result.released.length).to eq(0)
    end
  end

  describe 'no documents found' do
    it 'returns empty result' do
      extractor = mock_extractor_class.new([])
      detector = mock_change_detector_class.new(false)
      packager = mock_packager_class.new([])
      publisher = mock_publisher_class.new([])

      deps = described_class::Dependencies.new(
        extractor: extractor, filters: [],
        change_detector: detector, packager: packager,
        publisher: publisher, naming_registry: naming_registry,
        manifest: nil, channel_override: nil
      )

      config = described_class::Config.new(
        output_dir: '/tmp/docs', force: false,
        force_replace_patterns: nil, concurrency: 1,
        default_visibility: 'public'
      )

      result = described_class.new(deps).run(config)
      expect(result.released.length).to eq(0)
      expect(result.skipped.length).to eq(0)
    end
  end

  describe 'channel config validation' do
    let(:restrictive_config) do
      Metanorma::Release::ChannelConfig.from_yaml(<<~YAML)
        channels:
          - members/drafts
        defaults:
          visibility: public
      YAML
    end

    it 'filters out channels not in the config registry' do
      docs = [build_doc('cc-18011')]
      publisher = mock_publisher_class.new([])
      extractor = mock_extractor_class.new(docs)
      detector = mock_change_detector_class.new(false)
      packager = mock_packager_class.new([])

      deps = described_class::Dependencies.new(
        extractor: extractor, filters: [],
        change_detector: detector, packager: packager,
        publisher: publisher, naming_registry: naming_registry,
        manifest: nil, channel_override: nil,
        channel_config: restrictive_config
      )

      config = described_class::Config.new(
        output_dir: '/tmp/docs', force: true,
        force_replace_patterns: nil, concurrency: 1,
        default_visibility: 'public'
      )

      described_class.new(deps).run(config)
      published_channels = publisher.published.first[:channels]
      expect(published_channels).to be_empty
    end

    it 'keeps channels that are in the config registry' do
      docs = [build_doc('cc-18011')]
      publisher = mock_publisher_class.new([])
      extractor = mock_extractor_class.new(docs)
      detector = mock_change_detector_class.new(false)
      packager = mock_packager_class.new([])
      override = [Metanorma::Release::Channel.members('drafts')]

      deps = described_class::Dependencies.new(
        extractor: extractor, filters: [],
        change_detector: detector, packager: packager,
        publisher: publisher, naming_registry: naming_registry,
        manifest: nil, channel_override: override,
        channel_config: restrictive_config
      )

      config = described_class::Config.new(
        output_dir: '/tmp/docs', force: true,
        force_replace_patterns: nil, concurrency: 1,
        default_visibility: 'public'
      )

      described_class.new(deps).run(config)
      published_channels = publisher.published.first[:channels]
      expect(published_channels.length).to eq(1)
      expect(published_channels[0].to_s).to eq('members/drafts')
    end
  end
end
