# frozen_string_literal: true

class RecordingPublisher
  include Metanorma::Release::Publisher

  def initialize
    @published = []
  end

  attr_reader :published

  def publish(tag, _artifact, _metadata, channels:, force_replace: false)
    published << { tag: tag, channels: channels }
    Metanorma::Release::PublishResult.new(tag: tag, url: "mock://#{tag}",
                                          created?: true)
  end
end

class ConstantChangeDetector
  include Metanorma::Release::ChangeDetector

  def initialize(changed)
    @changed = changed
  end

  def detect(_metadata, _tag, force: false)
    Metanorma::Release::ChangeResult.new(
      changed?: force || @changed,
      current_hash: Metanorma::Release::ContentHash.from_hex("abc"),
      previous_hash: nil,
    )
  end
end

class RecordingPackager
  include Metanorma::Release::Packager

  def initialize
    @packaged = []
  end

  attr_reader :packaged

  def package(_metadata, canonical_base:)
    result = Metanorma::Release::Artifact.new(
      zip_path: "/tmp/#{canonical_base}.zip",
      asset_name: "#{canonical_base}.zip",
      size: 1024,
    )
    packaged << canonical_base
    result
  end
end

class FailingPublisher
  include Metanorma::Release::Publisher

  def publish(*)
    raise "Publishing failed"
  end
end

RSpec.describe Metanorma::Release::ReleasePipeline do
  let(:slug_registry) { Metanorma::Release::SlugRegistry.default }
  let(:compiled_dir) { File.join(__dir__, "../fixtures/integration/compiled") }

  describe "happy path" do
    it "releases changed documents and skips unchanged" do
      publisher = RecordingPublisher.new
      detector = ConstantChangeDetector.new(false)
      packager = RecordingPackager.new

      deps = described_class::Dependencies.new(
        extractor: Metanorma::Release::RxlExtractor,
        filters: [], change_detector: detector, packager: packager,
        publisher: publisher, slug_registry: slug_registry,
        manifest: nil, channel_override: nil
      )

      config = described_class::Config.new(
        output_dir: compiled_dir, force: true,
        force_replace_patterns: nil, concurrency: 1
      )

      result = described_class.new(deps).run(config)
      expect(result.released.length).to eq(2)
      expect(result.skipped.length).to eq(0)
      expect(result.released_artifacts.length).to eq(2)
    end
  end

  describe "change detection" do
    it "skips unchanged documents" do
      publisher = RecordingPublisher.new
      detector = ConstantChangeDetector.new(false)
      packager = RecordingPackager.new

      deps = described_class::Dependencies.new(
        extractor: Metanorma::Release::RxlExtractor,
        filters: [], change_detector: detector, packager: packager,
        publisher: publisher, slug_registry: slug_registry,
        manifest: nil, channel_override: nil
      )

      config = described_class::Config.new(
        output_dir: compiled_dir, force: false,
        force_replace_patterns: nil, concurrency: 1
      )

      result = described_class.new(deps).run(config)
      expect(result.skipped.length).to eq(2)
      expect(result.released.length).to eq(0)
    end
  end

  describe "channel resolution" do
    it "uses channel_override when set" do
      publisher = RecordingPublisher.new
      detector = ConstantChangeDetector.new(false)
      packager = RecordingPackager.new
      override = ["members"]

      deps = described_class::Dependencies.new(
        extractor: Metanorma::Release::RxlExtractor,
        filters: [], change_detector: detector, packager: packager,
        publisher: publisher, slug_registry: slug_registry,
        manifest: nil, channel_override: override
      )

      config = described_class::Config.new(
        output_dir: compiled_dir, force: true,
        force_replace_patterns: nil, concurrency: 1
      )

      described_class.new(deps).run(config)
      expect(publisher.published.first[:channels].map(&:to_s)).to eq(["members"])
    end
  end

  describe "error handling" do
    it "collects individual failures" do
      publisher = FailingPublisher.new
      detector = ConstantChangeDetector.new(false)
      packager = RecordingPackager.new

      deps = described_class::Dependencies.new(
        extractor: Metanorma::Release::RxlExtractor,
        filters: [], change_detector: detector, packager: packager,
        publisher: publisher, slug_registry: slug_registry,
        manifest: nil, channel_override: nil
      )

      config = described_class::Config.new(
        output_dir: compiled_dir, force: true,
        force_replace_patterns: nil, concurrency: 1
      )

      result = described_class.new(deps).run(config)
      expect(result.failed.length).to eq(2)
      expect(result.released.length).to eq(0)
    end
  end

  describe "no documents found" do
    it "returns empty result" do
      empty_dir = Dir.mktmpdir
      begin
        publisher = RecordingPublisher.new
        detector = ConstantChangeDetector.new(false)
        packager = RecordingPackager.new

        deps = described_class::Dependencies.new(
          extractor: Metanorma::Release::RxlExtractor,
          filters: [], change_detector: detector, packager: packager,
          publisher: publisher, slug_registry: slug_registry,
          manifest: nil, channel_override: nil
        )

        config = described_class::Config.new(
          output_dir: empty_dir, force: false,
          force_replace_patterns: nil, concurrency: 1
        )

        result = described_class.new(deps).run(config)
        expect(result.released.length).to eq(0)
        expect(result.skipped.length).to eq(0)
      ensure
        FileUtils.rm_rf(empty_dir)
      end
    end
  end

  describe "config-driven channel resolution" do
    it "uses config routing rules when config is provided" do
      config_yaml = <<~YAML
        channels:
          - public
          - internal
        routing:
          default: [public]
          rules:
            - stage: ["60"]
              channels: [public]
            - stage: ["30"]
              channels: [internal]
      YAML
      cfg = Metanorma::Release::Config.from_yaml(config_yaml)

      publisher = RecordingPublisher.new
      detector = ConstantChangeDetector.new(false)
      packager = RecordingPackager.new

      deps = described_class::Dependencies.new(
        extractor: Metanorma::Release::RxlExtractor,
        filters: [], change_detector: detector, packager: packager,
        publisher: publisher, slug_registry: slug_registry,
        manifest: nil, channel_override: nil,
        config: cfg
      )

      pipeline_config = described_class::Config.new(
        output_dir: compiled_dir, force: true,
        force_replace_patterns: nil, concurrency: 1
      )

      described_class.new(deps).run(pipeline_config)
      expect(publisher.published.first[:channels].map(&:to_s)).to eq(["public"])
    end
  end
end
