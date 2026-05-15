# frozen_string_literal: true

require "json"

module Metanorma
  module Release
    DocumentFile = Struct.new(:name, :path, keyword_init: true) do
      def extension
        File.extname(name).delete_prefix(".")
      end
    end

    DocumentSource = Struct.new(
      :owner, :repo, :tag, :release_url, :release_date,
      keyword_init: true
    ) do
      def repo_key
        "#{owner}/#{repo}"
      end
    end

    IndexParameters = Struct.new(
      :organizations, :channels, :topic, :repo_count,
      keyword_init: true
    )

    IndexSummary = Struct.new(
      :repo_count, :document_count, :channels_found,
      keyword_init: true
    )

    class AggregatedDocument
      def self.from_h(hash)
        files = (hash["files"] || []).map do |f|
          DocumentFile.new(name: f["name"], path: f["path"])
        end
        source_data = hash["source"] || {}
        source = DocumentSource.new(
          owner: source_data["owner"], repo: source_data["repo"],
          tag: source_data["tag"], release_url: source_data["releaseUrl"],
          release_date: source_data["releaseDate"]
        )
        new(
          id: hash["id"], title: hash["title"], edition: hash["edition"],
          stage: hash["stage"], doctype: hash.fetch("doctype", ""),
          channels: hash["channels"] || [], formats: hash["formats"] || [],
          flavor: hash["flavor"], content_hash: hash["contentHash"],
          source: source, files: files
        )
      end

      attr_reader :id, :title, :edition, :stage, :doctype, :channels,
                  :formats, :flavor, :content_hash, :source, :files

      def initialize(id:, title:, edition:, stage:, doctype:, channels:,
                     formats:, flavor:, content_hash:, source:, files:)
        @id = id
        @title = title
        @edition = edition
        @stage = stage
        @doctype = doctype
        @channels = channels.freeze
        @formats = formats.freeze
        @flavor = flavor
        @content_hash = content_hash
        @source = source
        @files = files.freeze
        freeze
      end

      def to_h
        {
          "id" => id, "title" => title, "edition" => edition,
          "stage" => stage, "doctype" => doctype,
          "channels" => channels, "formats" => formats,
          "flavor" => flavor, "contentHash" => content_hash,
          "source" => {
            "owner" => source.owner, "repo" => source.repo,
            "tag" => source.tag, "releaseUrl" => source.release_url,
            "releaseDate" => source.release_date
          },
          "files" => files.map { |f| { "name" => f.name, "path" => f.path } }
        }
      end
    end

    class DocumentIndex
      SCHEMA_VERSION = 1

      SchemaError = Class.new(StandardError)

      def self.from_json(json_string)
        data = JSON.parse(json_string)
        validate!(data)
        new(
          documents: (data["documents"] || []).map { |d| AggregatedDocument.from_h(d) },
          parameters: IndexParameters.new(
            organizations: data.dig("parameters", "organizations") || [],
            channels: data.dig("parameters", "channels") || [],
            topic: data.dig("parameters", "topic"),
            repo_count: data.dig("parameters", "repoCount") || 0
          ),
          generated_at: data["generatedAt"]
        )
      end

      def self.from_documents(documents, parameters:)
        new(documents: documents, parameters: parameters)
      end

      def initialize(documents:, parameters:, generated_at: nil)
        @documents = documents.freeze
        @parameters = parameters
        @generated_at = generated_at || Time.now.utc.iso8601
        freeze
      end

      def documents
        @documents
      end

      def parameters
        @parameters
      end

      def summary
        IndexSummary.new(
          repo_count: @parameters.repo_count,
          document_count: @documents.length,
          channels_found: channels
        )
      end

      def channels
        @documents.flat_map(&:channels).uniq.sort
      end

      def document_count
        @documents.length
      end

      def empty?
        @documents.empty?
      end

      def to_h
        {
          "version" => SCHEMA_VERSION,
          "generatedAt" => @generated_at,
          "parameters" => {
            "organizations" => @parameters.organizations,
            "channels" => @parameters.channels,
            "topic" => @parameters.topic,
            "repoCount" => @parameters.repo_count
          },
          "summary" => {
            "repoCount" => summary.repo_count,
            "documentCount" => summary.document_count,
            "channelsFound" => summary.channels_found
          },
          "documents" => @documents.map(&:to_h)
        }
      end

      def to_json(*_args)
        JSON.generate(to_h)
      end

      def write(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, to_json)
      end

      private

      def self.validate!(data)
        raise SchemaError, "Missing 'version' field" unless data.key?("version")
        raise SchemaError, "Unsupported schema version: #{data['version']}. Expected #{SCHEMA_VERSION}" unless data["version"] == SCHEMA_VERSION
        raise SchemaError, "Missing 'documents' field" unless data.key?("documents")

        data["documents"].each do |doc|
          raise SchemaError, "Document missing required field 'id'" unless doc.key?("id")
          raise SchemaError, "Document missing required field 'title'" unless doc.key?("title")
        end
      end
    end
  end
end
