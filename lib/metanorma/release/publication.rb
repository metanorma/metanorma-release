# frozen_string_literal: true

require "json"

module Metanorma
  module Release
    class PublicationFile
      attr_reader :format, :name, :path

      def initialize(format:, name:, path:)
        @format = format
        @name = name
        @path = path
        freeze
      end

      def eql?(other)
        other.is_a?(self.class) && format == other.format && path == other.path
      end

      def hash
        [format, path].hash
      end

      def to_h
        { "format" => format, "name" => name, "path" => path }
      end
    end

    class PublicationSource
      attr_reader :owner, :repo, :tag, :url, :date

      def initialize(owner:, repo:, tag:, url:, date:)
        @owner = owner
        @repo = repo
        @tag = tag
        @url = url
        @date = date
        freeze
      end

      def repo_key
        "#{owner}/#{repo}"
      end

      def eql?(other)
        other.is_a?(self.class) && owner == other.owner && repo == other.repo && tag == other.tag
      end

      def hash
        [owner, repo, tag].hash
      end

      def to_h
        { "owner" => owner, "repo" => repo, "tag" => tag,
          "releaseUrl" => url, "releaseDate" => date }
      end
    end

    class Publication
      METADATA_VERSION = 1

      DRAFT_STAGES = %w[
        20 30 40 50
        working-draft committee-draft draft-standard final-draft
      ].freeze

      attr_reader :identifier, :slug, :title, :edition, :stage, :doctype,
                  :revdate, :files, :channels, :source

      def initialize(identifier:, slug:, title:, edition:, stage:, doctype:,
                     revdate:, files:, channels:, source: nil, metadata_formats: nil)
        @identifier = identifier
        @slug = slug
        @title = title
        @edition = edition
        @stage = stage
        @doctype = doctype
        @revdate = revdate
        @files = files.freeze
        @channels = channels.freeze
        @source = source
        @metadata_formats = metadata_formats
        freeze
      end

      def formats
        @metadata_formats || files.map(&:format)
      end

      def base_dir
        files.any? ? File.dirname(files.first.path) : "."
      end

      def content_hash(from_directory: nil)
        dir = if from_directory && base_dir == "."
                from_directory
              else
                base_dir
              end
        ContentHash.of_directory(dir, base: slug)
      end

      def file?(format)
        formats.include?(format)
      end

      def draft?
        DRAFT_STAGES.include?(stage.to_s)
      end

      def eql?(other)
        other.is_a?(self.class) && identifier == other.identifier &&
          edition == other.edition && stage == other.stage
      end

      def hash
        [identifier, edition, stage].hash
      end

      def to_h
        h = {
          "id" => slug, "identifier" => identifier, "title" => title,
          "edition" => edition, "stage" => stage, "doctype" => doctype,
          "channels" => channels, "formats" => formats,
          "revdate" => revdate
        }
        h["source"] = source.to_h if source
        h["files"] = files.map(&:to_h) unless files.empty?
        h
      end

      def with_channels(new_channels)
        self.class.new(
          identifier: identifier, slug: slug, title: title,
          edition: edition, stage: stage, doctype: doctype,
          revdate: revdate, files: files,
          channels: new_channels, source: source,
          metadata_formats: @metadata_formats
        )
      end

      def with_files_and_source(new_files, release, repo)
        source = PublicationSource.new(
          owner: repo.owner, repo: repo.repo,
          tag: release.tag_name,
          url: release.html_url,
          date: release.published_at
        )
        pub_files = new_files.map do |f|
          name = File.basename(f)
          ext = File.extname(name).delete_prefix(".")
          PublicationFile.new(format: ext, name: name, path: f)
        end
        self.class.new(
          identifier: identifier, slug: slug, title: title,
          edition: edition, stage: stage, doctype: doctype,
          revdate: revdate, files: pub_files,
          channels: channels, source: source
        )
      end

      def to_release_body
        PublicationSerializer.to_release_body(self)
      end

      def to_json(*_args)
        PublicationSerializer.to_json(self)
      end

      def self.from_release_body(body)
        PublicationSerializer.from_release_body(body)
      end

      def self.from_json(json_string)
        PublicationSerializer.from_json(json_string)
      end

      def self.from_metadata_hash(data)
        ident = data["identifier"] || data["id"]
        new(
          identifier: ident,
          slug: SlugStrategy.slug_from_identifier(ident),
          title: data["title"],
          edition: data["edition"],
          stage: data["stage"],
          doctype: data["doctype"],
          revdate: data["revdate"],
          files: [],
          channels: data["channels"] || [],
          source: nil,
          metadata_formats: data["formats"],
        )
      end
    end
  end
end
