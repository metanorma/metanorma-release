# frozen_string_literal: true

module Metanorma
  module Release
    module SlugStrategy
      def compute_tag(publication)
        raise NotImplementedError, "#{self.class} must implement #compute_tag"
      end

      def compute_asset_name(publication)
        raise NotImplementedError,
              "#{self.class} must implement #compute_asset_name"
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
    end

    class EditionSlug
      include SlugStrategy

      def compute_tag(publication)
        tag = "#{publication.slug}/ed#{publication.edition}"
        { tag: tag, pre_release: publication.draft? }
      end

      def compute_asset_name(publication)
        "#{publication.slug}-ed#{publication.edition}.zip"
      end
    end

    class VersionSlug
      include SlugStrategy

      def compute_tag(publication)
        tag = "#{publication.slug}/v#{publication.edition}"
        { tag: tag, pre_release: publication.draft? }
      end

      def compute_asset_name(publication)
        "#{publication.slug}-v#{publication.edition}.zip"
      end
    end

    class InternetDraftSlug
      include SlugStrategy

      DRAFT_PATTERN = /\Adraft-ietf-([a-z0-9-]+?)-(\d+)\z/i

      def compute_tag(publication)
        match = publication.identifier.match(DRAFT_PATTERN)
        return fallback_tag(publication) unless match

        name = match[1]
        num = match[2]
        { tag: "id-#{name}/#{num}", pre_release: true }
      end

      def compute_asset_name(publication)
        "#{publication.identifier}.zip"
      end

      private

      def fallback_tag(publication)
        { tag: "#{publication.identifier}/draft", pre_release: true }
      end
    end

    class RfcSlug
      include SlugStrategy

      def compute_tag(publication)
        tag = "#{publication.slug}/ed#{publication.edition}"
        { tag: tag, pre_release: false }
      end

      def compute_asset_name(publication)
        "#{publication.slug}.zip"
      end
    end

    class DraftSuffixSlug
      include SlugStrategy

      DRAFT_SUFFIX = /-d(\d+)\z/

      def compute_tag(publication)
        match = publication.identifier.match(DRAFT_SUFFIX)
        return @fallback.compute_tag(publication) unless match

        base = publication.identifier.sub(DRAFT_SUFFIX, "")
        num = match[1]
        { tag: "#{base}/#{num}", pre_release: true }
      end

      def compute_asset_name(publication)
        match = publication.identifier.match(DRAFT_SUFFIX)
        return @fallback.compute_asset_name(publication) unless match

        "#{publication.slug}.zip"
      end

      def initialize
        @fallback = EditionSlug.new
      end
    end

    class SlugRegistry
      def initialize(default: EditionSlug.new)
        @default = default
        @strategies = {}
      end

      def register(publisher, strategy)
        @strategies[publisher.to_s] = strategy
      end

      def resolve(publisher)
        @strategies.fetch(publisher.to_s, @default)
      end

      def with_default(strategy)
        registry = new
        @strategies.each { |pub, s| registry.register(pub, s) }
        registry.set_default(strategy)
        registry
      end

      def set_default(strategy)
        @default = strategy
        self
      end

      def self.from_config(config)
        registry = new
        config.slug_strategies.each do |publisher, strategy_name|
          strategy = build_strategy(strategy_name)
          registry.register(publisher, strategy) if strategy
        end
        default = build_strategy(config.slug_default_strategy) || EditionSlug.new
        registry.set_default(default)
        registry
      end

      def self.build_strategy(name)
        case name.to_s
        when "edition"         then EditionSlug.new
        when "version"         then VersionSlug.new
        when "internet-draft"  then InternetDraftSlug.new
        when "rfc"             then RfcSlug.new
        when "draft-suffix"    then DraftSuffixSlug.new
        end
      end

      def self.default
        registry = new
        registry.register("ietf", InternetDraftSlug.new)
        registry.register("ieee", DraftSuffixSlug.new)
        registry.register("iho", VersionSlug.new)
        registry.register("ogc", VersionSlug.new)
        registry
      end
    end
  end
end
