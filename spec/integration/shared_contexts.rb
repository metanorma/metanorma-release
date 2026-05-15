# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'json'

RSpec.shared_context 'with compiled documents' do
  let(:compiled_dir) { File.join(__dir__, '../fixtures/integration/compiled') }
  let(:output_dir) { Dir.mktmpdir }
  after { FileUtils.rm_rf(output_dir) }
end

RSpec.shared_context 'with released documents' do
  let(:released_dir) { File.join(__dir__, '../fixtures/integration/released') }
  let(:output_dir) { Dir.mktmpdir }
  after { FileUtils.rm_rf(output_dir) }
end
