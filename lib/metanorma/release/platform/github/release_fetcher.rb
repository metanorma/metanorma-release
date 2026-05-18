# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module GitHub
        GitHubRelease = Struct.new(:tag_name, :body, :prerelease, :draft,
                                   :html_url, :published_at, :created_at,
                                   :assets, keyword_init: true)
        GitHubAsset = Struct.new(:name, :browser_download_url, :size, :data,
                                 keyword_init: true)

        class ReleaseFetcher
          include Metanorma::Release::ReleaseFetcher

          def initialize(client:)
            @client = client
          end

          def fetch(repo, etag: nil)
            releases = paginate_releases(repo.to_s)
            parsed = releases.map { |r| parse_release(r) }
            FetchResult.new(releases: parsed, etag: "etag-#{repo}",
                            unchanged?: false)
          end

          private

          def paginate_releases(repo_slug)
            @client.paginate("repos/#{repo_slug}/releases", per_page: 100)
          rescue StandardError => e
            warn "Warning: Failed to fetch releases for #{repo_slug}: #{e.message}"
            []
          end

          def parse_release(r)
            assets = (r[:assets] || []).map do |a|
              data = download_asset(a[:url]) if a[:name].end_with?(".zip")
              GitHubAsset.new(
                name: a[:name],
                browser_download_url: a[:browser_download_url],
                size: a[:size],
                data: data,
              )
            end
            GitHubRelease.new(
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
            @client.get(url, accept: "application/octet-stream")
          rescue StandardError => e
            warn "Warning: Failed to download asset #{url}: #{e.message}"
            nil
          end
        end
      end
    end
  end
end
