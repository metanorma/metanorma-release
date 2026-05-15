# frozen_string_literal: true

RSpec.describe Metanorma::Release::CLI do
  describe '.run' do
    it 'shows usage when no command given' do
      expect { described_class.run([]) }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(2)
      end
    end

    it 'shows error for unknown command' do
      expect { described_class.run(['foobar']) }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(2)
      end
    end
  end

  describe '.run_package' do
    it 'constructs pipeline with NullPublisher' do
      allow(Metanorma::Release::ReleasePipeline).to receive(:new).and_wrap_original do |m, *args|
        pipeline = m.call(*args)
        allow(pipeline).to receive(:run).and_return(
          Metanorma::Release::ReleaseResult.new(released: [], skipped: [], failed: [], released_artifacts: [])
        )
        pipeline
      end

      expect { described_class.run_package(['--output-dir', '/tmp']) }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(0)
      end
    end
  end

  describe '.run_publish' do
    it 'constructs pipeline with platform publisher' do
      allow(Metanorma::Release::ReleasePipeline).to receive(:new).and_wrap_original do |m, *args|
        pipeline = m.call(*args)
        allow(pipeline).to receive(:run).and_return(
          Metanorma::Release::ReleaseResult.new(released: [], skipped: [], failed: [], released_artifacts: [])
        )
        pipeline
      end

      expect do
        described_class.run_publish(['--platform', 'local', '--output-dir', '/tmp'])
      end.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(0)
      end
    end
  end

  describe 'exit codes' do
    it 'exits 1 on pipeline failure' do
      allow(Metanorma::Release::ReleasePipeline).to receive(:new).and_wrap_original do |m, *args|
        pipeline = m.call(*args)
        allow(pipeline).to receive(:run).and_return(
          Metanorma::Release::ReleaseResult.new(
            released: [], skipped: [],
            failed: [{ document: double(id: 'test'), error: 'boom' }],
            released_artifacts: []
          )
        )
        pipeline
      end

      expect { described_class.run_package(['--output-dir', '/tmp']) }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(1)
      end
    end
  end
end
