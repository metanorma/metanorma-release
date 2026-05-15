# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'zip'
require_relative 'shared_contexts'

RSpec.describe 'File routing modes', type: :integration do
  include_context 'with compiled documents'

  def run_with_routing(routing, output_dir)
    discoverer = Metanorma::Release::PlatformFactory::StaticDiscoverer.new(repos: [])
    fetcher = Metanorma::Release::Platform::Local::Fetcher.new(base_path: output_dir)
    manifest_reader = Metanorma::Release::PlatformFactory::NullManifestReader.new
    channel_filter = Metanorma::Release::ChannelFilter.new([])
    stage_filter = Metanorma::Release::StageFilter.new([])
    asset_processor = Metanorma::Release::AssetProcessor.new(output_dir: output_dir, routing: routing,
                                                             canonicalize: true)
    delta_state = Metanorma::Release::NullDeltaState.new

    deps = Metanorma::Release::AggregationPipeline::Dependencies.new(
      discoverer: discoverer, fetcher: fetcher, manifest_reader: manifest_reader,
      channel_filter: channel_filter, stage_filter: stage_filter,
      asset_processor: asset_processor, delta_state: delta_state
    )
    config = Metanorma::Release::AggregationPipeline::Config.new(
      organizations: [], channels: [], topic: nil,
      concurrency: 1, include_drafts: false, fail_on_error: false
    )
    Metanorma::Release::AggregationPipeline.new(deps).run(config, output_dir)
  end

  %w[by-document flat by-format].each do |mode|
    it "produces correct directory structure for #{mode}" do
      output_dir = Dir.mktmpdir
      begin
        routing = Metanorma::Release::FileRoutingFactory.from_name(mode)

        # Create a mock zip to process
        zip_data = create_test_zip('cc-18011', %w[html pdf xml])
        metadata = {
          'id' => 'cc-18011', 'title' => 'Test', 'edition' => '1',
          'stage' => 'published', 'channels' => ['public/standards']
        }

        result = asset_processor_instance(routing, output_dir).process(zip_data, metadata)
        expect(result.files.length).to be > 0

        result.files.each do |file|
          path = file.path
          expect(File.exist?(File.join(output_dir, path))).to be true

          case mode
          when 'by-document'
            expect(path).to start_with('cc-18011/')
          when 'flat'
            expect(path).not_to include('/')
          when 'by-format'
            ext = File.extname(file.name).delete_prefix('.')
            expect(path).to start_with("#{ext}/")
          end
        end
      ensure
        FileUtils.rm_rf(output_dir)
      end
    end
  end

  def asset_processor_instance(routing, output_dir)
    Metanorma::Release::AssetProcessor.new(output_dir: output_dir, routing: routing, canonicalize: true)
  end

  def create_test_zip(base_name, extensions)
    Dir.mktmpdir do |tmp|
      zip_path = File.join(tmp, 'test.zip')
      Zip::OutputStream.open(zip_path) do |zos|
        extensions.each do |ext|
          zos.put_next_entry("#{base_name}.#{ext}")
          zos.write("fake #{ext} content")
        end
      end
      File.binread(zip_path)
    end
  end
end
