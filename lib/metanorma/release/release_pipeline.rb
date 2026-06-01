# frozen_string_literal: true

module Metanorma
  module Release
    PublishResult = Struct.new(:tag, :url, :created?, keyword_init: true)
    ReleasedArtifact = Struct.new(:id, :tag, :url, :channels,
                                  keyword_init: true)
    ReleaseResult = Struct.new(:released, :skipped, :failed,
                               :released_artifacts, keyword_init: true)

    class ReleasePipeline
      Dependencies = Struct.new(
        :extractor, :filters, :change_detector,
        :packager, :publisher, :slug_registry,
        :manifest, :channel_override, :config,
        keyword_init: true
      ) do
        include DependencyValidation

        def initialize(**kwargs)
          super
          validate_types!
        end

        private

        def validate_types!
          unless extractor.is_a?(Class) && extractor.singleton_class.ancestors.include?(Extractor)
            raise ArgumentError,
                  "extractor must extend Extractor, got #{extractor}"
          end

          validate_interface!(change_detector, ChangeDetector,
                              "change_detector")
          validate_interface!(packager, Packager, "packager")
          validate_interface!(publisher, Publisher, "publisher")
        end
      end

      Config = Struct.new(
        :output_dir, :force, :force_replace_patterns,
        :concurrency,
        keyword_init: true
      )

      def initialize(deps)
        @deps = deps
      end

      def run(config)
        publications = @deps.extractor.discover(config.output_dir)
        filtered = apply_filters(publications)
        results = phase_one(filtered, config)
        phase_two(results, config)
      end

      private

      def apply_filters(publications)
        return publications unless @deps.filters && !@deps.filters.empty?

        @deps.filters.reduce(publications) { |docs, filter| filter.apply(docs) }
      end

      def phase_one(publications, config)
        publications.map do |pub|
          publisher = SlugStrategy.publisher_from_identifier(pub.identifier)
          strategy = @deps.slug_registry.resolve(publisher)
          tag_info = strategy.compute_tag(pub)
          canonical_base = strategy.compute_asset_name(pub).sub(/\.zip$/, "")
          change = @deps.change_detector.detect(pub, tag_info[:tag],
                                                force: config.force)

          { publication: pub, tag: tag_info[:tag], pre_release: tag_info[:pre_release],
            canonical_base: canonical_base, changed: change.changed?, change_result: change }
        end
      end

      def phase_two(candidates, config)
        released = []
        skipped = []
        failed = []
        released_artifacts = []

        candidates.each do |candidate|
          pub = candidate[:publication]
          tag = candidate[:tag]

          unless candidate[:changed]
            skipped << pub
            next
          end

          begin
            channels = resolve_channels(pub)
            if channels.empty?
              skipped << pub
              next
            end

            artifact = @deps.packager.package(pub,
                                              canonical_base: candidate[:canonical_base])
            channel_objects = channels.map { |c| Channel.new(c) }
            pub_for_release = pub.with_channels(channels)
            force = config.force_replace_patterns&.any? do |p|
              File.fnmatch?(p, pub.slug)
            end || false

            result = @deps.publisher.publish(tag, artifact, pub_for_release,
                                             channels: channel_objects, force_replace: force)
            released << pub
            released_artifacts << ReleasedArtifact.new(
              id: pub.slug, tag: tag.to_s,
              url: result.url, channels: channels
            )
          rescue StandardError => e
            failed << { document: pub, error: e.message }
          end
        end

        ReleaseResult.new(released: released, skipped: skipped, failed: failed,
                          released_artifacts: released_artifacts)
      end

      def resolve_channels(pub)
        override = @deps.channel_override
        return override if override && !override.empty?

        if @deps.config
          @deps.config.resolve_channels(pub)
        elsif @deps.manifest
          policy = @deps.manifest.resolve(pub)
          policy&.channels&.map(&:to_s) || ["public"]
        else
          ["public"]
        end
      end
    end
  end
end
