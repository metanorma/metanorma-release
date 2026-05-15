# frozen_string_literal: true

RSpec.describe Metanorma::Release::PublishCommand do
  let(:success_result) do
    Metanorma::Release::ReleaseResult.new(
      released: [], skipped: [], failed: [], released_artifacts: []
    )
  end

  it 'constructs pipeline with platform publisher' do
    allow(Metanorma::Release::ReleasePipeline).to receive(:new).and_wrap_original do |m, *args|
      pipeline = m.call(*args)
      allow(pipeline).to receive(:run).and_return(success_result)
      pipeline
    end

    config = described_class::Config.new(
      output_dir: '/tmp/test_pub', platform: 'local',
      manifest: 'nonexistent.yml', force: false,
      force_replace: [], channels: nil, concurrency: 4,
      token: nil, config_source: nil
    )
    result = described_class.new(config).call

    expect(result).to eq(success_result)
  end

  it 'passes channel override when channels specified' do
    allow(Metanorma::Release::ReleasePipeline).to receive(:new).and_wrap_original do |m, *args|
      pipeline = m.call(*args)
      allow(pipeline).to receive(:run).and_return(success_result)
      pipeline
    end

    config = described_class::Config.new(
      output_dir: '/tmp/test_pub', platform: 'local',
      manifest: 'nonexistent.yml', force: false,
      force_replace: [], channels: ['public/default'],
      concurrency: 4, token: nil, config_source: nil
    )
    result = described_class.new(config).call

    expect(result).to eq(success_result)
  end
end
