# frozen_string_literal: true

begin
  require "relaton/bib"
rescue LoadError
  raise LoadError,
        "The relaton-bib gem is required. Add `gem 'relaton-bib'` to your Gemfile."
end

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

      def content_hash
        ContentHash.of_directory(base_dir, base: slug)
      end

      def file?(format)
        formats.include?(format)
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
        "<!-- mn-release-metadata\n#{JSON.generate(metadata_hash)}\n-->"
      end

      def to_json(*_args)
        JSON.generate(metadata_hash)
      end

      def self.from_json(json_string)
        data = JSON.parse(json_string)
        raise ArgumentError, "Missing required field: id" unless data["id"]
        unless data["title"]
          raise ArgumentError,
                "Missing required field: title"
        end

        from_metadata_hash(data)
      end

      def self.from_release_body(body)
        return nil if body.nil? || body.empty?

        match = body.match(/<!--\s*mn-release-metadata\s*\n(.*?)\n-->/m)
        return nil unless match

        from_json(match[1])
      rescue JSON::ParserError
        nil
      end

      def self.from_metadata_hash(data)
        ident = data["identifier"] || data["id"]
        new(
          identifier: ident,
          slug: slug_from_identifier(ident),
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

      private

      def metadata_hash
        {
          "version" => METADATA_VERSION,
          "id" => slug,
          "identifier" => identifier,
          "title" => title,
          "edition" => edition,
          "stage" => stage,
          "doctype" => doctype,
          "revdate" => revdate,
          "formats" => formats,
          "channels" => channels,
          "publisher" => Publication.publisher_from_identifier(identifier),
        }
      end

      def self.slug_from_identifier(identifier)
        identifier.to_s.strip
          .gsub(/\s+/, "-")
          .gsub(/:+/, "-")
          .downcase
          .gsub(/--+/, "-")
          .gsub(/[-.]+$/, "")
      end

      def self.publisher_from_identifier(identifier)
        return nil if identifier.nil? || identifier.strip.empty?

        identifier.strip.split(/[\s-]/).first&.downcase
      end

      # -- RXL extraction --

      def self.discover(output_dir)
        Dir.glob(File.join(output_dir, "**", "*.rxl")).filter_map do |path|
          from_rxl(path)
        rescue StandardError => e
          warn "Warning: Skipping #{path}: #{e.message}"
          nil
        end
      end

      def self.from_rxl(rxl_path)
        unless File.exist?(rxl_path)
          raise ArgumentError,
                "RXL file not found: #{rxl_path}"
        end

        content = File.read(rxl_path)
        bib = Relaton::Bib::Item.from_xml(content)
        build_from_bib(bib, rxl_path)
      rescue StandardError => e
        warn "Warning: Failed to parse RXL #{rxl_path}: #{e.message}"
        fallback_from_rxl(rxl_path)
      end

      class << self
        private

        def build_from_bib(bib, rxl_path)
          identifier = bib.docidentifier&.first&.content || ""
          slug = slug_from_identifier(identifier)
          output_dir = File.dirname(rxl_path)
          base_name = File.basename(rxl_path, ".rxl")

          new(
            identifier: identifier, slug: slug,
            title: bib.title&.first&.content || "",
            edition: extract_edition(bib),
            stage: extract_stage(bib),
            doctype: extract_doctype(bib),
            revdate: extract_revdate(bib),
            files: discover_files(output_dir, base_name),
            channels: [], source: nil
          )
        end

        def extract_edition(bib)
          ed = bib.edition
          return "1" unless ed

          ed.respond_to?(:content) ? ed.content.to_s : ed.to_s
        end

        def extract_stage(bib)
          stage = bib.status&.stage
          return "" unless stage

          stage.respond_to?(:content) ? stage.content.to_s : stage.to_s
        end

        def extract_doctype(bib)
          doctype = bib.ext&.doctype
          return "" unless doctype

          doctype.respond_to?(:content) ? doctype.content.to_s : doctype.to_s
        end

        def extract_revdate(bib)
          date = bib.date&.find { |d| d.type == "published" } || bib.date&.first
          return nil unless date

          on = date.on
          on.respond_to?(:content) ? on.content.to_s : on.to_s
        rescue StandardError
          nil
        end

        def discover_files(output_dir, base_name)
          Dir.glob(File.join(output_dir, "#{base_name}.*")).filter_map do |path|
            next if File.directory?(path)

            name = File.basename(path)
            ext = File.extname(name).delete_prefix(".")
            PublicationFile.new(format: ext, name: name, path: name)
          end
        end

        def fallback_from_rxl(rxl_path)
          base_name = File.basename(rxl_path, ".rxl")
          slug = slug_from_identifier(base_name)
          new(
            identifier: base_name, slug: slug, title: "",
            edition: "0", stage: "", doctype: "",
            revdate: nil, files: [], channels: [], source: nil
          )
        end
      end
    end
  end
end
