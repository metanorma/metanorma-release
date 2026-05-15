# frozen_string_literal: true

require 'yaml'

module Metanorma
  module Release
    class AggregateConfig
      attr_reader :source, :organizations, :topic, :repos, :repo_pattern,
                  :channels, :stages, :output_dir, :file_routing,
                  :local_path

      def self.load(path = nil)
        path ||= find_config
        return default unless path && File.exist?(path)

        new(YAML.safe_load(File.read(path)))
      end

      def self.find_config
        %w[metanorma.aggregate.yml metanorma.yml].find { |f| File.exist?(f) }
      end

      def self.default
        new({})
      end

      def initialize(data)
        @source = data['source'] || 'github'
        @output_dir = data['output_dir'] || '_site/cc'
        @file_routing = data['file_routing'] || 'by-document'
        @channels = data['channels'] || []
        @stages = data['stages'] || []

        src = data[@source] || {}
        @organizations = src['organizations'] || []
        @topic = src['topic'] || 'metanorma-release'
        @repos = src['repos']
        @repo_pattern = src['repo_pattern']
        @local_path = src['path']
      end
    end
  end
end
