# frozen_string_literal: true

module Metanorma
  module Release
    class ReleasePipeline
      Dependencies = Struct.new(
        :extractor, :filters, :change_detector,
        :packager, :publisher, :naming_registry,
        :manifest, :channel_override, :channel_config,
        keyword_init: true
      )

      Config = Struct.new(
        :output_dir, :manifest_path, :force, :force_replace_patterns,
        :concurrency, :default_visibility,
        keyword_init: true
      )

      def initialize(deps)
        @deps = deps
      end

      def run(config)
        documents = @deps.extractor.discover(config.output_dir)
        filtered = apply_filters(documents)
        results = phase_one(filtered, config)
        phase_two(results, config)
      end

      private

      def apply_filters(documents)
        return documents unless @deps.filters && !@deps.filters.empty?

        @deps.filters.reduce(documents) { |docs, filter| filter.apply(docs) }
      end

      def phase_one(documents, config)
        documents.map do |doc|
          strategy = @deps.naming_registry.resolve(doc.document_type)
          tag = strategy.compute_tag(doc.id.to_s, doc.version)
          canonical_base = strategy.compute_canonical_base(doc.id.to_s, doc.version)
          change = @deps.change_detector.detect(doc, tag, force: config.force)

          { document: doc, tag: tag, canonical_base: canonical_base,
            changed: change.changed?, change_result: change }
        end
      end

      def phase_two(candidates, config)
        released = []
        skipped = []
        failed = []
        released_artifacts = []

        candidates.each do |candidate|
          doc = candidate[:document]
          tag = candidate[:tag]

          unless candidate[:changed]
            skipped << doc
            next
          end

          begin
            policy = resolve_policy(doc, config)
            unless policy.release?
              skipped << doc
              next
            end

            artifact = @deps.packager.package(doc, canonical_base: candidate[:canonical_base])
            channels = resolve_channels(doc, policy)
            metadata_json = ReleaseMetadata.from_document(doc, channels: channels)
            force = config.force_replace_patterns&.any? { |p| File.fnmatch?(p, doc.id.to_s) } || false

            result = @deps.publisher.publish(tag, artifact, metadata_json, channels: channels, force_replace: force)
            released << doc
            released_artifacts << ReleasedArtifact.new(
              id: doc.id.to_s, tag: tag.to_s,
              url: result.url, channels: channels.map(&:to_s)
            )
          rescue StandardError => e
            failed << { document: doc, error: e.message }
          end
        end

        ReleaseResult.new(released: released, skipped: skipped, failed: failed,
                          released_artifacts: released_artifacts)
      end

      def resolve_policy(doc, config)
        return @deps.manifest.resolve(doc) if @deps.manifest

        DocumentReleasePolicy.from_defaults("public", [Channel.public("default")])
      end

      def resolve_channels(doc, policy)
        channels = if @deps.channel_override && !@deps.channel_override.empty?
                     @deps.channel_override
                   else
                     policy.channels
                   end

        validate_channels(channels)
      end

      def validate_channels(channels)
        return channels unless @deps.channel_config

        channels.select { |ch| @deps.channel_config.registry.valid?(ch) }
      end
    end
  end
end
