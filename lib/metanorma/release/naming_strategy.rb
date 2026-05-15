# frozen_string_literal: true

module Metanorma
  module Release
    module NamingStrategy
      def compute_tag(id, version)
        raise NotImplementedError, "#{self.class} must implement #compute_tag"
      end

      def compute_asset_name(id, version)
        raise NotImplementedError, "#{self.class} must implement #compute_asset_name"
      end

      def compute_canonical_base(id, version)
        raise NotImplementedError, "#{self.class} must implement #compute_canonical_base"
      end
    end

    class EditionNaming
      include NamingStrategy

      def compute_tag(id, version)
        tag = "#{id}/#{version.tag_component}"
        ReleaseTag.create(tag, pre_release: version.pre_release?)
      end

      def compute_asset_name(id, version)
        "#{id}-#{version.tag_component}.zip"
      end

      def compute_canonical_base(id, version)
        "#{id}-#{version.tag_component}"
      end
    end

    class VersionNaming
      include NamingStrategy

      def compute_tag(id, version)
        tag = "#{id}/v#{version.edition}"
        ReleaseTag.create(tag, pre_release: version.pre_release?)
      end

      def compute_asset_name(id, version)
        "#{id}-v#{version.edition}.zip"
      end

      def compute_canonical_base(id, version)
        "#{id}-v#{version.edition}"
      end
    end

    class InternetDraftNaming
      include NamingStrategy

      DRAFT_PATTERN = /\Adraft-ietf-([a-z0-9-]+?)-(\d+)\z/i

      def compute_tag(id, version)
        match = id.match(DRAFT_PATTERN)
        return fallback_tag(id, version) unless match

        name = match[1]
        num = match[2]
        ReleaseTag.create("id-#{name}/#{num}", pre_release: true)
      end

      def compute_asset_name(id, _version)
        "#{id}.zip"
      end

      def compute_canonical_base(id, _version)
        id.to_s
      end

      private

      def fallback_tag(id, _version)
        tag = "#{id}/draft"
        ReleaseTag.create(tag, pre_release: true)
      end
    end

    class RfcNaming
      include NamingStrategy

      def compute_tag(id, version)
        tag = "#{id}/ed#{version.edition}"
        ReleaseTag.create(tag, pre_release: version.pre_release?)
      end

      def compute_asset_name(id, _version)
        "#{id}.zip"
      end

      def compute_canonical_base(id, version)
        "#{id}-ed#{version.edition}"
      end
    end

    class DraftSuffixNaming
      include NamingStrategy

      DRAFT_SUFFIX = /-d(\d+)\z/

      def compute_tag(id, version)
        match = id.to_s.match(DRAFT_SUFFIX)
        return @fallback.compute_tag(id, version) unless match

        base = id.to_s.sub(DRAFT_SUFFIX, '')
        num = match[1]
        ReleaseTag.create("#{base}/#{num}", pre_release: true)
      end

      def compute_asset_name(id, version)
        match = id.to_s.match(DRAFT_SUFFIX)
        return @fallback.compute_asset_name(id, version) unless match

        "#{id}.zip"
      end

      def compute_canonical_base(id, version)
        match = id.to_s.match(DRAFT_SUFFIX)
        return @fallback.compute_canonical_base(id, version) unless match

        id.to_s
      end

      def initialize
        @fallback = EditionNaming.new
      end
    end

    class NamingRegistry
      def initialize(default: EditionNaming.new)
        @default = default
        @strategies = {}
      end

      def register(document_type, strategy)
        @strategies[document_type] = strategy
      end

      def resolve(document_type)
        @strategies.fetch(document_type, @default)
      end

      def self.default_registry
        registry = new
        registry.register(DocumentType::IETF_DRAFT, InternetDraftNaming.new)
        registry.register(DocumentType::IETF_RFC,   RfcNaming.new)
        registry.register(DocumentType::IEEE,       DraftSuffixNaming.new)
        registry.register(DocumentType::IHO,        VersionNaming.new)
        registry.register(DocumentType::OGC,        VersionNaming.new)
        registry
      end
    end
  end
end
