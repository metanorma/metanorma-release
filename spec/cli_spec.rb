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
    it 'delegates to PackageCommand and exits 0 on success' do
      result = Metanorma::Release::ReleaseResult.new(
        released: [], skipped: [], failed: [], released_artifacts: []
      )
      cmd = instance_double(Metanorma::Release::PackageCommand)
      allow(Metanorma::Release::PackageCommand).to receive(:new).and_return(cmd)
      allow(cmd).to receive(:call).and_return(result)

      expect { described_class.run_package(['--output-dir', '/tmp']) }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(0)
      end
    end
  end

  describe '.run_publish' do
    it 'delegates to PublishCommand and exits 0 on success' do
      result = Metanorma::Release::ReleaseResult.new(
        released: [], skipped: [], failed: [], released_artifacts: []
      )
      cmd = instance_double(Metanorma::Release::PublishCommand)
      allow(Metanorma::Release::PublishCommand).to receive(:new).and_return(cmd)
      allow(cmd).to receive(:call).and_return(result)

      expect do
        described_class.run_publish(['--platform', 'local', '--output-dir', '/tmp'])
      end.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(0)
      end
    end
  end

  describe 'exit codes' do
    it 'exits 1 on pipeline failure' do
      result = Metanorma::Release::ReleaseResult.new(
        released: [], skipped: [],
        failed: [{ document: double(id: 'test'), error: 'boom' }],
        released_artifacts: []
      )
      cmd = instance_double(Metanorma::Release::PackageCommand)
      allow(Metanorma::Release::PackageCommand).to receive(:new).and_return(cmd)
      allow(cmd).to receive(:call).and_return(result)

      expect { described_class.run_package(['--output-dir', '/tmp']) }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(1)
      end
    end
  end
end
