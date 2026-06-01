# frozen_string_literal: true

module Metanorma
  module Release
    FetchResult = Struct.new(:releases, :etag, :unchanged?, keyword_init: true)
    RepoReport  = Struct.new(:releases, :included, :skipped, :reason, :errors,
                             keyword_init: true)
    RepoError   = Struct.new(:tag, :message, keyword_init: true)

    class AggregationPipeline
      Dependencies = Struct.new(
        :discoverer, :fetcher, :manifest_reader,
        :metadata_filter, :asset_processor, :delta_state,
        keyword_init: true
      ) do
        include DependencyValidation

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

        if config.concurrency > 1
          publications, reports, failed_repos = run_concurrent(repos,
                                                               output_dir, config)
        else
          publications, reports, failed_repos = run_sequential(repos,
                                                               output_dir, config)
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

      def run_sequential(repos, output_dir, config)
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

        [publications, reports, failed_repos]
      end

      def run_concurrent(repos, output_dir, config)
        publications = []
        reports = []
        failed_repos = []
        mutex = Mutex.new
        threads = repos.each_slice([
          (repos.length.to_f / config.concurrency).ceil, 1
        ].max).map do |batch|
          Thread.new(batch) do |slice|
            slice.each do |repo|
              repo_docs, report = process_repo(repo, output_dir, config)
              mutex.synchronize do
                publications.concat(repo_docs)
                reports << report
              end
            rescue StandardError => e
              mutex.synchronize do
                failed_repos << RepoError.new(tag: repo.to_s,
                                              message: e.message)
              end
              raise if config.fail_on_error
            end
          end
        end
        threads.each { |t| t.join(300) }

        [publications, reports, failed_repos]
      end

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

          cached_files = @deps.delta_state.release_files(repo_key, tag)
          if cached_files.any? && cached_files.all? do |f|
            File.exist?(File.join(output_dir, f))
          end
            publications << build_publication(metadata, cached_files, release,
                                              repo)
            next
          end

          zip_asset = find_zip_asset(release)
          next unless zip_asset

          result = @deps.asset_processor.process(zip_asset.data, metadata_h)
          @deps.delta_state.mark_processed(repo_key, tag, nil,
                                           result.files.map(&:path))
          publications << build_publication(metadata, result.files.map(&:path),
                                            release, repo)
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

      def build_publication(metadata, files, release, repo)
        metadata.with_files_and_source(files, release, repo)
      end

      def find_zip_asset(release)
        return nil unless release.assets

        release.assets.find { |a| a.name.end_with?(".zip") }
      end
    end
  end
end
