# frozen_string_literal: true

require "json"

module Metanorma
  module Release
    class DeltaState
      def initialize(cache_store:, output_dir:)
        @cache = cache_store
        @output_dir = output_dir
        @state = empty_state
      end

      def load
        raw = @cache.get("delta_state")
        return if raw.nil?

        @state = JSON.parse(raw)
      rescue JSON::ParserError
        @state = empty_state
      end

      def save
        @cache.set("delta_state", JSON.generate(@state))
      end

      def etag(repo_key)
        repo_state(repo_key)["etag"]
      end

      def set_etag(repo_key, etag_value)
        repo = ensure_repo(repo_key)
        repo["etag"] = etag_value
      end

      def processed?(repo_key, tag, content_hash)
        releases = repo_state(repo_key)["releases"]
        return false unless releases.key?(tag)
        return false if content_hash.nil?

        releases[tag]["content_hash"] == content_hash.to_s
      end

      def release_files(repo_key, tag)
        releases = repo_state(repo_key)["releases"]
        return [] unless releases.key?(tag)

        releases[tag]["files"] || []
      end

      def mark_processed(repo_key, tag, content_hash, files)
        repo = ensure_repo(repo_key)
        repo["releases"][tag] = {
          "content_hash" => content_hash.to_s,
          "files" => files
        }
      end

      def cleanup_stale(repo_key, current_tags)
        repo = repo_state(repo_key)
        releases = repo["releases"]
        removed = 0

        releases.each do |tag, entry|
          next if current_tags.include?(tag)

          (entry["files"] || []).each do |file|
            path = File.join(@output_dir, file)
            if File.exist?(path)
              File.delete(path)
              removed += 1
            end
          end
          releases.delete(tag)
        end

        removed
      end

      private

      def empty_state
        { "last_run" => Time.now.utc.iso8601, "repos" => {} }
      end

      def repo_state(repo_key)
        @state["repos"][repo_key] || { "etag" => nil, "releases" => {} }
      end

      def ensure_repo(repo_key)
        @state["repos"][repo_key] ||= { "etag" => nil, "releases" => {} }
      end
    end

    class NullDeltaState
      def initialize; end

      def load; end
      def save; end
      def etag(_repo_key) = nil
      def set_etag(_repo_key, _etag) = nil
      def processed?(*_args) = false
      def release_files(*_args) = []
      def mark_processed(*_args); end
      def cleanup_stale(*_args) = 0
    end
  end
end
