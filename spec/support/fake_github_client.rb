# frozen_string_literal: true

module Metanorma
  module Release
    class FakeGitHubClient
      def initialize(releases: [], search_results: [], contents: {})
        @releases = releases
        @search_results = search_results
        @contents = contents
        @created_releases = []
      end

      attr_reader :created_releases

      def releases(_repo)
        @releases
      end

      def get(url, **)
        return @releases if url.include?("/releases")

        []
      end

      def create_release(_repo, tag_name, name: nil, body: nil,
prerelease: false)
        result = {
          "html_url" => "https://github.com/test/test/releases/tag/#{tag_name}",
          "id" => @created_releases.length + 1,
          "tag_name" => tag_name, "name" => name, "body" => body,
          "prerelease" => prerelease
        }
        @created_releases << result
        result
      end

      def update_release(url, _opts = {})
        { "html_url" => url }
      end

      def delete_release?(_url)
        true
      end
      alias delete_release delete_release?

      def delete_ref?(_repo, _ref)
        true
      end
      alias delete_ref delete_ref?

      def upload_asset?(*)
        true
      end
      alias upload_asset upload_asset?

      def search_repositories(_query, **)
        { items: @search_results }
      end

      def contents(_repo, path: nil)
        content = @contents[path]
        raise StandardError, "Not found" unless content

        { "content" => Base64.strict_encode64(content) }
      end
    end
  end
end
