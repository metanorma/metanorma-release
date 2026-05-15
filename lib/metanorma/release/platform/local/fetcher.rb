# frozen_string_literal: true

require 'json'

module Metanorma
  module Release
    module Platform
      module Local
        class Fetcher
          include Metanorma::Release::ReleaseFetcher

          DRAFT_STAGES = %w[working-draft committee-draft draft-standard final-draft].freeze

          def initialize(base_path:)
            @base_path = base_path
          end

          def fetch(repo, etag: nil)
            dir = File.join(@base_path, repo.repo)
            return FetchResult.new(releases: [], etag: nil, unchanged?: false) unless Dir.exist?(dir)

            releases = Dir.glob(File.join(dir, '*.meta.json')).filter_map do |meta_path|
              build_release(dir, meta_path)
            end

            FetchResult.new(releases: releases, etag: nil, unchanged?: false)
          end

          private

          def build_release(dir, meta_path)
            data = JSON.parse(File.read(meta_path))
            base = File.basename(meta_path, '.meta.json')
            zip_path = File.join(dir, "#{base}.zip")

            unless File.exist?(zip_path)
              warn "Warning: Missing zip for #{meta_path}, skipping"
              return nil
            end

            metadata = ReleaseMetadata.new(data)
            asset = AssetData.new(
              name: "#{base}.zip",
              browser_download_url: "file://#{File.expand_path(zip_path)}",
              size: File.size(zip_path),
              data: File.binread(zip_path)
            )

            mtime = File.mtime(zip_path).iso8601
            ReleaseData.new(
              tag_name: "#{data['id']}/#{data.fetch('edition', '1')}",
              body: metadata.to_release_body,
              prerelease: prerelease?(data),
              draft: false,
              html_url: "file://#{File.expand_path(dir)}",
              published_at: mtime,
              created_at: mtime,
              assets: [asset]
            )
          rescue JSON::ParserError
            warn "Warning: Invalid metadata JSON in #{meta_path}, skipping"
            nil
          end

          def prerelease?(data)
            DRAFT_STAGES.include?(data['stage'].to_s)
          end
        end
      end
    end
  end
end
