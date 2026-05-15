# frozen_string_literal: true

RSpec.describe Metanorma::Release::AggregateCommand do
  let(:success_result) do
    Metanorma::Release::AggregationPipeline::Result.new(
      documents: [], repo_count: 0, channels_found: [],
      report: [], failed_repos: []
    )
  end

  it 'constructs aggregation pipeline and runs it' do
    allow(Metanorma::Release::AggregationPipeline).to receive(:new).and_wrap_original do |m, *args|
      pipeline = m.call(*args)
      allow(pipeline).to receive(:run).and_return(success_result)
      pipeline
    end

    config = described_class::Config.new(
      source: 'local:/tmp/test_agg', organizations: [], topic: 'test',
      repos: nil, channels: [], stages: [], output_dir: '/tmp/test_out',
      file_routing: 'by-document', cache_dir: nil,
      include_drafts: false, concurrency: 4, min_documents: 0,
      token: nil, zip: nil
    )
    result = described_class.new(config).call

    expect(result).to eq(success_result)
  end

  it 'does not zip when zip flag is nil' do
    allow(Metanorma::Release::AggregationPipeline).to receive(:new).and_wrap_original do |m, *args|
      pipeline = m.call(*args)
      allow(pipeline).to receive(:run).and_return(success_result)
      pipeline
    end

    config = described_class::Config.new(
      source: 'local:/tmp/test_agg', organizations: [], topic: 'test',
      repos: nil, channels: [], stages: [], output_dir: '/tmp/test_out',
      file_routing: 'by-document', cache_dir: nil,
      include_drafts: false, concurrency: 4, min_documents: 0,
      token: nil, zip: nil
    )

    expect { described_class.new(config).call }.not_to raise_error
  end
end
