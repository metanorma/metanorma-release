# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Metanorma::Release::CLI do
  describe "package" do
    it "succeeds when no documents to process" do
      tmpdir = Dir.mktmpdir
      begin
        expect do
          described_class.start(["package", "--output-dir", tmpdir])
        end.not_to raise_error
      ensure
        FileUtils.rm_rf(tmpdir)
      end
    end
  end

  describe "release" do
    it "succeeds when no documents to process" do
      tmpdir = Dir.mktmpdir
      begin
        expect do
          described_class.start(["release", "--platform", "null", "--output-dir",
                                 tmpdir])
        end.not_to raise_error
      ensure
        FileUtils.rm_rf(tmpdir)
      end
    end
  end

  describe "unknown command" do
    it "outputs error message" do
      expect do
        described_class.start(["foobar"])
      rescue SystemExit
        nil
      end.to output(/Could not find command/).to_stderr
    end
  end

  describe "help" do
    it "lists available commands" do
      expect do
        described_class.start(["help"])
      end.to output(/aggregate.*package.*release/m).to_stdout
    end
  end

  describe "version" do
    it "prints version" do
      expect do
        described_class.start(["version"])
      end.to output(/metanorma-release/).to_stdout
    end

    it "responds to --version flag" do
      expect do
        described_class.start(["--version"])
      end.to output(/metanorma-release/).to_stdout
    end
  end

  describe "--verbose flag" do
    it "sets logger to DEBUG level" do
      expect do
        described_class.start(["package", "--verbose"])
      end.to output(/Packaged/).to_stdout
      expect(Metanorma::Release.logger.level).to eq(Logger::DEBUG)
    end
  end

  describe "--quiet flag" do
    it "sets logger to ERROR level" do
      expect do
        described_class.start(["package", "--quiet"])
      end.to output(/Packaged/).to_stdout
      expect(Metanorma::Release.logger.level).to eq(Logger::ERROR)
    end
  end
end
