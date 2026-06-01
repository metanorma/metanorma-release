# frozen_string_literal: true

require "digest"

module Metanorma
  module Release
    module Platform
      module GitHub
        class ReleaseFetcher
          include Metanorma::Release::ReleaseFetcher

          def initialize(client:, download_cache_dir: nil)
            @client = client
            @download_cache_dir = download_cache_dir
          end

          def fetch(repo, etag: nil)
            releases = paginate_releases(repo.to_s)
            parsed = releases.map { |r| parse_release(r) }
            FetchResult.new(releases: parsed, etag: "etag-#{repo}",
                            unchanged?: false)
          end

          private

          def paginate_releases(repo_slug)
            all = []
            page = 1
            loop do
              resp = @client.get("repos/#{repo_slug}/releases?per_page=100&page=#{page}")
              break if resp.nil? || resp.empty?

              all.concat(resp)
              break if resp.length < 100

              page += 1
            end
            all
          rescue StandardError => e
            Metanorma::Release.logger.warn "Failed to fetch releases for #{repo_slug}: #{e.message}"
            []
          end

          def parse_release(r)
            assets = (r[:assets] || []).map do |a|
              data = download_asset(a[:url]) if a[:name].end_with?(".zip")
              Asset.new(
                name: a[:name],
                browser_download_url: a[:browser_download_url],
                size: a[:size],
                data: data,
              )
            end
            Release.new(
              tag_name: r[:tag_name],
              body: r[:body],
              prerelease: r[:prerelease],
              draft: r[:draft],
              html_url: r[:html_url],
              published_at: r[:published_at],
              created_at: r[:created_at],
              assets: assets,
            )
          end

          def download_asset(url)
            cache_path = cache_file_path(url)
            if cache_path && File.exist?(cache_path)
              return File.binread(cache_path)
            end

            data = @client.get(url, accept: "application/octet-stream")
            if cache_path && data
              FileUtils.mkdir_p(File.dirname(cache_path))
              File.binwrite(cache_path, data)
            end
            data
          rescue StandardError => e
            Metanorma::Release.logger.warn "Failed to download asset #{url}: #{e.message}"
            nil
          end

          def cache_file_path(url)
            return nil unless @download_cache_dir

            hash = Digest::SHA256.hexdigest(url)
            File.join(@download_cache_dir, hash)
          end
        end
      end
    end
  end
end
