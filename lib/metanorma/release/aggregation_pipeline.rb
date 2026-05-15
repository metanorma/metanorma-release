# frozen_string_literal: true

module Metanorma
  module Release
    class AggregationPipeline
      Dependencies = Struct.new(
        :discoverer, :fetcher, :manifest_reader,
        :channel_filter, :stage_filter,
        :asset_processor, :delta_state,
        keyword_init: true
      )

      Config = Struct.new(
        :organizations, :channels, :topic,
        :concurrency, :include_drafts, :fail_on_error,
        keyword_init: true
      )

      Result = Struct.new(
        :documents, :repo_count, :channels_found,
        :report, :failed_repos,
        keyword_init: true
      )

      def initialize(deps)
        @deps = deps
      end

      def run(config, output_dir)
        @deps.delta_state.load
        repos = @deps.discoverer.discover
        documents = []
        reports = []
        failed_repos = []

        repos.each do |repo|
          repo_docs, report = process_repo(repo, output_dir, config)
          documents.concat(repo_docs)
          reports << report
        rescue StandardError => e
          failed_repos << RepoError.new(tag: repo.to_s, message: e.message)
          raise if config.fail_on_error
        end

        @deps.delta_state.save

        Result.new(
          documents: documents,
          repo_count: repos.length,
          channels_found: documents.flat_map { |d| d.channels || [] }.uniq.sort,
          report: reports,
          failed_repos: failed_repos
        )
      end

      private

      def process_repo(repo, _output_dir, config)
        repo_key = repo.to_s

        manifest_channels = @deps.manifest_reader.read(repo)
        if manifest_channels && !@deps.channel_filter.overlaps?(manifest_channels)
          return [], RepoReport.new(releases: 0, included: 0, skipped: 0,
                                    reason: 'channel manifest', errors: [])
        end

        etag = @deps.delta_state.etag(repo_key)
        fetch_result = @deps.fetcher.fetch(repo, etag: etag)

        if fetch_result.unchanged?
          return [], RepoReport.new(releases: 0, included: 0, skipped: 0,
                                    reason: 'etag unchanged', errors: [])
        end

        current_tags = []
        documents = []
        errors = []

        fetch_result.releases.each do |release|
          metadata = ReleaseMetadata.from_release_body(release.body)
          next if metadata.nil?

          next unless @deps.channel_filter.matches?(metadata.to_h)
          next unless @deps.stage_filter.matches?(metadata.to_h)
          next if release.prerelease && !config.include_drafts

          tag = release.tag_name
          current_tags << tag

          content_hash = extract_content_hash(release.body)

          if @deps.delta_state.processed?(repo_key, tag, content_hash)
            files = @deps.delta_state.release_files(repo_key, tag)
            documents << build_document(metadata, files, content_hash, release, repo)
            next
          end

          zip_asset = find_zip_asset(release)
          next unless zip_asset

          result = @deps.asset_processor.process(zip_asset.data, metadata.to_h)
          @deps.delta_state.mark_processed(repo_key, tag, content_hash, result.files.map(&:path))
          documents << build_document(metadata, result.files.map(&:path), content_hash, release, repo)
        rescue StandardError => e
          errors << RepoError.new(tag: release.tag_name, message: e.message)
        end

        @deps.delta_state.cleanup_stale(repo_key, current_tags)
        @deps.delta_state.set_etag(repo_key, fetch_result.etag)

        [documents, RepoReport.new(
          releases: fetch_result.releases.length,
          included: documents.length,
          skipped: fetch_result.releases.length - documents.length,
          reason: nil, errors: errors
        )]
      end

      def build_document(metadata, files, content_hash, release, repo)
        source = DocumentSource.new(
          owner: repo.owner, repo: repo.repo,
          tag: release.tag_name,
          release_url: release.html_url,
          release_date: release.published_at
        )

        file_structs = files.map { |f| DocumentFile.new(name: File.basename(f), path: f) }

        AggregatedDocument.new(
          id: metadata.id, title: metadata.title,
          edition: metadata.edition, stage: metadata.stage,
          doctype: metadata.doctype,
          channels: metadata.channels,
          formats: metadata.formats,
          flavor: metadata.flavor,
          content_hash: content_hash.to_s,
          source: source, files: file_structs
        )
      end

      def extract_content_hash(body)
        return nil if body.nil?

        match = body.match(/^content-hash:([a-f0-9]+)/)
        match ? match[1] : nil
      end

      def find_zip_asset(release)
        return nil unless release.assets

        release.assets.find { |a| a.name.end_with?('.zip') }
      end
    end
  end
end
