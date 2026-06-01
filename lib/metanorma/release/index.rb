# frozen_string_literal: true

require "json"

module Metanorma
  module Release
    class Index
      SCHEMA_VERSION = 1

      class SchemaError < StandardError
      end

      attr_reader :publications, :parameters, :generated_at

      def initialize(publications:, parameters:, generated_at: nil)
        @publications = publications.freeze
        @parameters = parameters
        @generated_at = generated_at || Time.now.utc.iso8601
        freeze
      end

      def channels
        @publications.flat_map(&:channels).uniq.sort
      end

      def publication_count
        @publications.length
      end

      def empty?
        @publications.empty?
      end

      def to_h
        {
          "version" => SCHEMA_VERSION,
          "generatedAt" => @generated_at,
          "parameters" => {
            "organizations" => @parameters[:organizations] || [],
            "channels" => @parameters[:channels] || [],
            "topic" => @parameters[:topic],
            "repoCount" => @parameters[:repo_count] || 0,
          },
          "summary" => {
            "repoCount" => @parameters[:repo_count] || 0,
            "documentCount" => publication_count,
            "channelsFound" => channels,
          },
          "documents" => @publications.map(&:to_h),
        }
      end

      def to_json(*_args)
        JSON.pretty_generate(to_h)
      end

      def write(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, to_json)
      end

      def self.from_documents(publications, parameters:)
        new(publications: publications, parameters: parameters)
      end

      def self.from_json(json_string)
        data = JSON.parse(json_string)
        validate!(data)
        publications = (data["documents"] || []).map do |d|
          publication_from_h(d)
        end
        new(
          publications: publications,
          parameters: {
            organizations: data.dig("parameters", "organizations") || [],
            channels: data.dig("parameters", "channels") || [],
            topic: data.dig("parameters", "topic"),
            repo_count: data.dig("parameters", "repoCount") || 0,
          },
          generated_at: data["generatedAt"],
        )
      end

      def self.validate!(data)
        raise SchemaError, "Missing 'version' field" unless data.key?("version")
        unless data["version"] == SCHEMA_VERSION
          raise SchemaError,
                "Unsupported schema version: #{data['version']}. Expected #{SCHEMA_VERSION}"
        end
        unless data.key?("documents")
          raise SchemaError,
                "Missing 'documents' field"
        end

        data["documents"].each do |doc|
          unless doc.key?("id")
            raise SchemaError,
                  "Document missing required field 'id'"
          end
        end
      end

      def self.publication_from_h(hash)
        files = (hash["files"] || []).map do |f|
          PublicationFile.new(format: f["format"], name: f["name"],
                              path: f["path"])
        end
        source = if hash["source"]
                   PublicationSource.new(
                     owner: hash["source"]["owner"],
                     repo: hash["source"]["repo"],
                     tag: hash["source"]["tag"],
                     url: hash["source"]["releaseUrl"],
                     date: hash["source"]["releaseDate"],
                   )
                 end
        Publication.new(
          identifier: hash["identifier"] || hash["id"],
          slug: hash["id"],
          title: hash["title"],
          edition: hash["edition"],
          stage: hash["stage"],
          doctype: hash.fetch("doctype", ""),
          revdate: hash["revdate"],
          channels: hash["channels"] || [],
          files: files,
          source: source,
        )
      end
    end
  end
end
