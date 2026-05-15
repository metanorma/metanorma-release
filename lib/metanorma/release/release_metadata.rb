# frozen_string_literal: true

require 'json'

module Metanorma
  module Release
    class ReleaseMetadata
      SCHEMA_VERSION = 1

      def self.from_document(metadata, channels:)
        data = {
          'version' => SCHEMA_VERSION,
          'id' => metadata.id.to_s,
          'title' => metadata.title,
          'edition' => metadata.version.edition,
          'stage' => metadata.version.stage.to_s,
          'doctype' => metadata.doctype.to_s,
          'revdate' => metadata.revdate,
          'formats' => metadata.formats,
          'channels' => channels.map(&:to_s),
          'flavor' => metadata.flavor,
          'sourcePath' => metadata.source_path
        }
        new(data)
      end

      def self.from_json(json_string)
        data = JSON.parse(json_string)
        raise ArgumentError, 'Missing required field: id' unless data['id']
        raise ArgumentError, 'Missing required field: title' unless data['title']

        new(data)
      end

      def self.from_release_body(body)
        return nil if body.nil? || body.empty?

        match = body.match(/<!--\s*mn-release-metadata\s*\n(.*?)\n-->/m)
        return nil unless match

        json_str = match[1]
        begin
          from_json(json_str)
        rescue JSON::ParserError
          nil
        end
      end

      def initialize(data)
        @data = data
        freeze
      end

      def to_json(*_args)
        JSON.generate(@data)
      end

      def to_release_body
        json_str = JSON.generate(@data)
        "<!-- mn-release-metadata\n#{json_str}\n-->"
      end

      def to_h
        @data.dup
      end

      def id         = @data['id']
      def title      = @data['title']
      def edition    = @data['edition']
      def stage      = @data['stage']
      def doctype    = @data['doctype']
      def revdate    = @data['revdate']
      def formats    = @data['formats'] || []
      def channels   = @data['channels'] || []
      def flavor     = @data['flavor']
      def source_path = @data['sourcePath']
    end
  end
end
