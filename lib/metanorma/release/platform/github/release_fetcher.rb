# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module GitHub
        class ReleaseFetcher
          include Metanorma::Release::ReleaseFetcher

          def initialize(client:)
            @client = client
          end

          def fetch(repo, etag: nil)
            releases = @client.releases(repo.to_s)
            parsed = releases.map { |r| parse_release(r) }
            FetchResult.new(releases: parsed, etag: "etag-#{repo}", unchanged?: false)
          end

          private

          def parse_release(r)
            assets = (r[:assets] || []).map do |a|
              AssetData.new(
                name: a[:name],
                browser_download_url: a[:browser_download_url],
                size: a[:size],
                data: nil
              )
            end
            ReleaseData.new(
              tag_name: r[:tag_name],
              body: r[:body],
              prerelease: r[:prerelease],
              draft: r[:draft],
              html_url: r[:html_url],
              published_at: r[:published_at],
              created_at: r[:created_at],
              assets: assets
            )
          end
        end
      end
    end
  end
end
