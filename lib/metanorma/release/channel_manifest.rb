# frozen_string_literal: true

require 'yaml'

module Metanorma
  module Release
    class DocumentReleasePolicy
      def self.from_defaults(visibility, channels)
        ch = build_channels(visibility, channels)
        is_released = visibility != 'private' || !ch.empty?
        new(release: is_released, channels: ch, stage_allow_list: nil)
      end

      def self.from_entry(entry)
        ch = build_channels(entry.visibility, entry.channels)
        new(release: true, channels: ch, stage_allow_list: entry.stages_set)
      end

      def self.not_released
        new(release: false, channels: [].freeze, stage_allow_list: nil)
      end

      def initialize(release:, channels:, stage_allow_list:)
        @release = release
        @channels = channels.freeze
        @stage_allow_list = stage_allow_list
        freeze
      end

      def release?
        @release
      end

      attr_reader :channels, :stage_allow_list

      def self.build_channels(visibility, explicit_channels)
        return explicit_channels if explicit_channels && !explicit_channels.empty?

        case visibility
        when 'public'  then [Channel.public('default')]
        when 'members' then [Channel.members('default')]
        else [].freeze
        end
      end
    end

    class ManifestEntry
      attr_reader :source, :pattern, :visibility, :channels, :stages

      def initialize(source:, pattern:, visibility:, channels:, stages:)
        @source = source
        @pattern = pattern
        @visibility = visibility
        @channels = channels
        @stages = stages
        freeze
      end

      def match_priority
        return 100 if source
        return 50 + pattern.to_s.length if pattern

        0
      end

      def stages_set
        return nil if stages.nil? || stages.empty?

        Set.new(stages.map(&:downcase))
      end
    end

    class ChannelManifest
      def self.parse(yaml_hash)
        defaults = yaml_hash['defaults'] || {}
        default_visibility = defaults['visibility'] || 'public'
        default_channels = parse_channels(defaults['channels'])
        entries = parse_entries(yaml_hash['documents'] || [])
        config_source = yaml_hash['config']

        new(entries: entries, default_visibility: default_visibility,
            default_channels: default_channels, explicit: true, config_source: config_source)
      end

      def self.from_yaml(yaml_string)
        yaml = YAML.safe_load(yaml_string, permitted_classes: [Symbol])
        raise ArgumentError, 'Manifest YAML is empty' unless yaml.is_a?(Hash)

        parse(yaml)
      end

      def self.from_file(path)
        raise ArgumentError, "Manifest file not found: #{path}" unless File.exist?(path)

        from_yaml(File.read(path))
      end

      def self.all_public
        new(entries: [], default_visibility: 'public',
            default_channels: [Channel.public('default')], explicit: false, config_source: nil)
      end

      def self.all_private
        new(entries: [], default_visibility: 'private',
            default_channels: [], explicit: false, config_source: nil)
      end

      def initialize(entries:, default_visibility:, default_channels:, explicit:, config_source: nil)
        @entries = entries
        @default_visibility = default_visibility
        @default_channels = default_channels.freeze
        @explicit = explicit
        @config_source = config_source
        freeze
      end

      def resolve(document)
        return default_policy unless @explicit

        entry = find_best_match(document)
        return DocumentReleasePolicy.from_defaults(@default_visibility, @default_channels) unless entry

        DocumentReleasePolicy.from_entry(entry)
      end

      def list_all
        @entries
      end

      def all_channels
        (@default_channels + @entries.flat_map(&:channels)).uniq
      end

      def explicit?
        @explicit
      end

      attr_reader :config_source

      private

      def default_policy
        DocumentReleasePolicy.from_defaults(@default_visibility, @default_channels)
      end

      def find_best_match(document)
        source = extract_source(document)
        matches = @entries.select { |e| entry_matches?(e, source) }
        return nil if matches.empty?

        matches.max_by(&:match_priority)
      end

      def entry_matches?(entry, source)
        return false unless source
        return true if entry.source && entry.source == source
        return true if entry.pattern && File.fnmatch?(entry.pattern, source)

        false
      end

      def extract_source(document)
        document['source_path']
      end

      def self.parse_channels(channel_list)
        return [] unless channel_list

        channel_list.map { |c| Channel.parse(c.to_s) }
      end

      def self.parse_entries(documents)
        documents.map do |doc|
          validate_entry!(doc)
          ManifestEntry.new(
            source: doc['source'],
            pattern: doc['pattern'],
            visibility: doc['visibility'],
            channels: parse_channels(doc['channels']),
            stages: doc['stages']
          )
        end
      end

      def self.validate_entry!(doc)
        return unless doc['source']&.include?('..')

        raise ArgumentError, "Path traversal detected in manifest source: #{doc['source']}"
      end
    end
  end
end
