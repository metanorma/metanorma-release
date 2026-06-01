# frozen_string_literal: true

require "json"

module Metanorma
  module Release
    module Platform
      module Local
        class Fetcher
          include Metanorma::Release::ReleaseFetcher

          def initialize(base_path:)
            @base_path = base_path
          end

          def fetch(repo, etag: nil)
            dir = File.join(@base_path, repo.repo)
            unless Dir.exist?(dir)
              return FetchResult.new(releases: [], etag: nil,
                                     unchanged?: false)
            end

            releases = Dir.glob(File.join(dir,
                                          "*.meta.json")).filter_map do |meta_path|
              build_release(dir, meta_path)
            end

            FetchResult.new(releases: releases, etag: nil, unchanged?: false)
          end

          private

          def build_release(dir, meta_path)
            data = JSON.parse(File.read(meta_path))
            base = File.basename(meta_path, ".meta.json")
            zip_path = File.join(dir, "#{base}.zip")

            unless File.exist?(zip_path)
              Metanorma::Release.logger.warn "Missing zip for #{meta_path}, skipping"
              return nil
            end

            metadata = Publication.from_metadata_hash(data)
            asset = Asset.new(
              name: "#{base}.zip",
              browser_download_url: "file://#{File.expand_path(zip_path)}",
              size: File.size(zip_path),
              data: File.binread(zip_path),
            )

            Release.new(
              tag_name: "#{metadata.slug}/#{metadata.edition || '1'}",
              body: metadata.to_release_body,
              prerelease: metadata.draft?,
              draft: false,
              html_url: "file://#{File.expand_path(dir)}",
              published_at: File.mtime(zip_path).iso8601,
              created_at: File.mtime(zip_path).iso8601,
              assets: [asset],
            )
          rescue JSON::ParserError
            Metanorma::Release.logger.warn "Invalid metadata JSON in #{meta_path}, skipping"
            nil
          end
        end
      end
    end
  end
end
