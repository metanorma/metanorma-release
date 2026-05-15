# frozen_string_literal: true

RSpec.describe Metanorma::Release::PackageCommand do
  let(:success_result) do
    Metanorma::Release::ReleaseResult.new(
      released: [], skipped: [], failed: [], released_artifacts: []
    )
  end

  it 'constructs pipeline with null publisher and runs it' do
    allow(Metanorma::Release::ReleasePipeline).to receive(:new).and_wrap_original do |m, *args|
      pipeline = m.call(*args)
      allow(pipeline).to receive(:run).and_return(success_result)
      pipeline
    end

    config = described_class::Config.new(
      output_dir: '/tmp/test_pkg', dest: 'dist',
      manifest: 'nonexistent.yml', config_source: nil
    )
    result = described_class.new(config).call

    expect(result).to eq(success_result)
  end

  it 'passes channel_config from config_source resolution' do
    channel_config = Metanorma::Release::ChannelConfig.empty
    allow(Metanorma::Release::ChannelConfig).to receive(:empty).and_return(channel_config)

    config = described_class::Config.new(
      output_dir: '/tmp/test_pkg', dest: 'dist',
      manifest: 'nonexistent.yml', config_source: nil
    )
    described_class.new(config).call

    expect(Metanorma::Release::ChannelConfig).to have_received(:empty)
  end
end
