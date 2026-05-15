# frozen_string_literal: true

require 'rake'

RSpec.describe Metanorma::Release::RakeTasks do
  it 'defines mn:package task' do
    app = Rake::Application.new
    Rake.application = app
    begin
      described_class.install do |t|
        t.output_dir = '/tmp/test'
        t.dest = '/tmp/test/dist'
      end
      expect(Rake::Task.task_defined?('mn:package')).to be true
    ensure
      Rake.application = Rake::Application.new
    end
  end

  it 'defines mn:publish task' do
    app = Rake::Application.new
    Rake.application = app
    begin
      described_class.install
      expect(Rake::Task.task_defined?('mn:publish')).to be true
    ensure
      Rake.application = Rake::Application.new
    end
  end

  it 'defines mn:aggregate task' do
    app = Rake::Application.new
    Rake.application = app
    begin
      described_class.install
      expect(Rake::Task.task_defined?('mn:aggregate')).to be true
    ensure
      Rake.application = Rake::Application.new
    end
  end

  it 'config block sets defaults' do
    config = nil
    described_class.install do |t|
      t.output_dir = 'custom/_site'
      config = t
    end
    expect(config.output_dir).to eq('custom/_site')
  end
end
