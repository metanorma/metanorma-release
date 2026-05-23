# frozen_string_literal: true

module Metanorma
  module Release
    FetchResult = Struct.new(:releases, :etag, :unchanged?, keyword_init: true)
    RepoReport  = Struct.new(:releases, :included, :skipped, :reason, :errors,
                             keyword_init: true)
    RepoError   = Struct.new(:tag, :message, keyword_init: true)

    class AggregationPipeline # rubocop:disable Metrics/ClassLength
      Dependencies = Struct.new(
        :discoverer, :fetcher, :manifest_reader,
        :metadata_filter, :asset_processor, :delta_state,
        keyword_init: true
      ) do
        def initialize(**kwargs)
          super
          validate_types!
        end

        private

        def validate_types!
          validate_interface!(discoverer, RepoDiscoverer, "discoverer")
          validate_interface!(fetcher, ReleaseFetcher, "fetcher")
          validate_interface!(manifest_reader, ManifestReader,
                              "manifest_reader")
          validate_interface!(delta_state, DeltaStateManager, "delta_state")
        end

        def validate_interface!(obj, mod, name)
          return if obj.is_a?(mod) || begin
            obj.class.ancestors.include?(mod)
          rescue StandardError
            false
          end

          raise ArgumentError, "#{name} must include #{mod}, got #{obj.class}"
        end
      end

      Config = Struct.new(
        :organizations, :channels, :topic,
        :concurrency, :include_drafts, :fail_on_error,
        keyword_init: true
      )

      Result = Struct.new(
        :publications, :repo_count, :channels_found,
        :report, :failed_repos,
        keyword_init: true
      )

      def initialize(deps)
        @deps = deps
      end

      def run(config, output_dir)
        @deps.delta_state.load
        repos = @deps.discoverer.discover
        publications = []
        reports = []
        failed_repos = []

        repos.each do |repo|
          repo_docs, report = process_repo(repo, output_dir, config)
          publications.concat(repo_docs)
          reports << report
        rescue StandardError => e
          failed_repos << RepoError.new(tag: repo.to_s, message: e.message)
          raise if config.fail_on_error
        end

        @deps.delta_state.save

        Result.new(
          publications: publications,
          repo_count: repos.length,
          channels_found: publications.flat_map(&:channels).uniq.sort,
          report: reports,
          failed_repos: failed_repos,
        )
      end

      private

      def process_repo(repo, output_dir, config)
        repo_key = repo.to_s

        manifest_channels = @deps.manifest_reader.read(repo)
        if manifest_channels && !@deps.metadata_filter.overlaps?(manifest_channels)
          return [], RepoReport.new(releases: 0, included: 0, skipped: 0,
                                    reason: "channel manifest", errors: [])
        end

        etag = @deps.delta_state.etag(repo_key)
        fetch_result = @deps.fetcher.fetch(repo, etag: etag)

        if fetch_result.unchanged?
          return [], RepoReport.new(releases: 0, included: 0, skipped: 0,
                                    reason: "etag unchanged", errors: [])
        end

        current_tags = []
        publications = []
        errors = []

        fetch_result.releases.each do |release|
          metadata = Publication.from_release_body(release.body)
          next if metadata.nil?

          metadata_h = metadata.to_h
          next unless @deps.metadata_filter.matches?(metadata_h)
          next if release.prerelease && !config.include_drafts

          tag = release.tag_name
          current_tags << tag

          content_hash = extract_content_hash(release.body)

          if @deps.delta_state.processed?(repo_key, tag, content_hash)
            files = @deps.delta_state.release_files(repo_key, tag)
            if files.all? { |f| File.exist?(File.join(output_dir, f)) }
              publications << build_publication(metadata, files, content_hash,
                                                release, repo)
              next
            end
          end

          zip_asset = find_zip_asset(release)
          next unless zip_asset

          result = @deps.asset_processor.process(zip_asset.data, metadata_h)
          @deps.delta_state.mark_processed(repo_key, tag, content_hash,
                                           result.files.map(&:path))
          publications << build_publication(metadata, result.files.map(&:path),
                                            content_hash, release, repo)
        rescue StandardError => e
          errors << RepoError.new(tag: release.tag_name, message: e.message)
        end

        @deps.delta_state.cleanup_stale(repo_key, current_tags)
        @deps.delta_state.set_etag(repo_key, fetch_result.etag)

        [publications, RepoReport.new(
          releases: fetch_result.releases.length,
          included: publications.length,
          skipped: fetch_result.releases.length - publications.length,
          reason: nil, errors: errors
        )]
      end

      def build_publication(metadata, files, _content_hash, release, repo)
        metadata.with_files_and_source(files, release, repo)
      end

      def extract_content_hash(body)
        return nil if body.nil?

        match = body.match(/^content-hash:([a-f0-9]+)/)
        match ? match[1] : nil
      end

      def find_zip_asset(release)
        return nil unless release.assets

        release.assets.find { |a| a.name.end_with?(".zip") }
      end
    end
  end
end
