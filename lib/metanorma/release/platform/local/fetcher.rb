# frozen_string_literal: true

require "json"

module Metanorma
  module Release
    module Platform
      module Local
        LocalRelease = Struct.new(:tag_name, :body, :prerelease, :draft,
                                  :html_url, :published_at, :created_at,
                                  :assets, keyword_init: true)
        LocalAsset = Struct.new(:name, :browser_download_url, :size, :data,
                                keyword_init: true)

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
              warn "Warning: Missing zip for #{meta_path}, skipping"
              return nil
            end

            metadata = Publication.from_metadata_hash(data)
            asset = LocalAsset.new(
              name: "#{base}.zip",
              browser_download_url: "file://#{File.expand_path(zip_path)}",
              size: File.size(zip_path),
              data: File.binread(zip_path),
            )

            LocalRelease.new(
              tag_name: "#{metadata.slug}/#{metadata.edition || '1'}",
              body: metadata.to_release_body,
              prerelease: prerelease?(metadata),
              draft: false,
              html_url: "file://#{File.expand_path(dir)}",
              published_at: File.mtime(zip_path).iso8601,
              created_at: File.mtime(zip_path).iso8601,
              assets: [asset],
            )
          rescue JSON::ParserError
            warn "Warning: Invalid metadata JSON in #{meta_path}, skipping"
            nil
          end

          def prerelease?(metadata)
            stage = metadata.stage.to_s
            %w[working-draft committee-draft draft-standard
               final-draft].include?(stage)
          end
        end
      end
    end
  end
end
