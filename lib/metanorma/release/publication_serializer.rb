# frozen_string_literal: true

module Metanorma
  module Release
    module PublicationSerializer
      METADATA_COMMENT_PATTERN = /<!--\s*mn-release-metadata\s*\n(.*?)\n-->/m

      def self.to_release_body(publication)
        "<!-- mn-release-metadata\n#{JSON.generate(metadata_hash(publication))}\n-->"
      end

      def self.from_release_body(body)
        return nil if body.nil? || body.empty?

        match = body.match(METADATA_COMMENT_PATTERN)
        return nil unless match

        from_json(match[1])
      rescue JSON::ParserError
        nil
      end

      def self.to_json(publication)
        JSON.generate(metadata_hash(publication))
      end

      def self.from_json(json_string)
        data = JSON.parse(json_string)
        raise ArgumentError, "Missing required field: id" unless data["id"]
        unless data["title"]
          raise ArgumentError,
                "Missing required field: title"
        end

        Publication.from_metadata_hash(data)
      end

      class << self
        private

        def metadata_hash(publication)
          {
            "version" => Publication::METADATA_VERSION,
            "id" => publication.slug,
            "identifier" => publication.identifier,
            "title" => publication.title,
            "edition" => publication.edition,
            "stage" => publication.stage,
            "doctype" => publication.doctype,
            "revdate" => publication.revdate,
            "formats" => publication.formats,
            "channels" => publication.channels,
            "publisher" => SlugStrategy.publisher_from_identifier(publication.identifier),
          }
        end
      end
    end
  end
end
