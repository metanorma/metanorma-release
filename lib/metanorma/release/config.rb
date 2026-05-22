# frozen_string_literal: true

require "yaml"

module Metanorma
  module Release
    class Config
      def self.from_yaml(yaml_string)
        data = YAML.safe_load(yaml_string, permitted_classes: [Symbol])
        new(data || {})
      end

      def self.from_file(path)
        unless File.exist?(path)
          raise ArgumentError,
                "Config file not found: #{path}"
        end

        from_yaml(File.read(path))
      end

      def self.defaults
        new({})
      end

      def initialize(data)
        @data = data
      end

      def org
        @data["org"]
      end

      def channels
        @data.fetch("channels", [])
      end

      def slug_config
        @data.fetch("slug", {})
      end

      def slug_default_strategy
        slug_config.fetch("default", "edition")
      end

      def slug_strategies
        slug_config.fetch("strategies", {})
      end

      def documents
        @data.fetch("documents", [])
      end

      def document_entries
        @document_entries ||= documents.map { |d| DocumentEntry.new(d) }
      end

      def resolve_channels(publication)
        ChannelResolver.resolve(publication, self)
      end
    end

    # Single routing entry — matches by any combination of pattern, source,
    # stage, and doctype. An entry with no criteria matches everything (catch-all).
    DocumentEntry = Struct.new(:pattern, :source, :stages, :doctypes, :channels, keyword_init: true) do
      def initialize(data)
        super(
          pattern: data["pattern"],
          source: data["source"],
          stages: Array(data["stage"]).map(&:to_s),
          doctypes: Array(data["doctype"]).map(&:to_s),
          channels: Array(data["channels"]).map(&:to_s),
        )
      end

      def matches?(publication)
        return false if channels.empty?

        if pattern && !File.fnmatch?(pattern, publication.slug)
          return false
        end

        if source && !(publication.source_path&.end_with?(source) || false)
          return false
        end

        if !stages.empty? && !stages.include?(publication.stage.to_s)
          return false
        end

        if !doctypes.empty? && !doctypes.include?(publication.doctype.to_s)
          return false
        end

        true
      end
    end

    # Iterates document entries: first match wins. Falls back to ["public"].
    class ChannelResolver
      FALLBACK = ["public"].freeze

      def self.resolve(publication, config)
        config.document_entries.each do |entry|
          return entry.channels if entry.matches?(publication)
        end
        FALLBACK
      end
    end
  end
end
