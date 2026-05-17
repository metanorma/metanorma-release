# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module GitHub
        class Publisher
          include Metanorma::Release::Publisher

          def initialize(client:, repo:)
            @client = client
            @repo = repo
          end

          def publish(tag, artifact, metadata, channels:, force_replace: false)
            tag_name = tag.to_s

            if force_replace
              delete_existing_release(tag_name)
              return create_release(tag_name, metadata, artifact,
                                    prerelease: channels_pre_release?(channels))
            end

            existing = find_release(tag_name)

            if existing
              update_release(existing, metadata)
            else
              create_release(tag_name, metadata, artifact,
                             prerelease: channels_pre_release?(channels))
            end
          end

          private

          def channels_pre_release?(channels)
            channels.any? do |c|
              c.to_s.include?("draft") || c.to_s.include?("internal")
            end
          end

          def find_release(tag_name)
            @client.releases(@repo).find { |r| r["tag_name"] == tag_name }
          rescue StandardError
            nil
          end

          def create_release(tag_name, metadata, artifact, prerelease: false)
            release = @client.create_release(
              @repo, tag_name,
              name: tag_name,
              body: metadata.to_release_body,
              prerelease: prerelease
            )
            upload_asset(release["id"], artifact)
            PublishResult.new(tag: tag_name, url: release["html_url"],
                              created?: true)
          end

          def update_release(release, metadata)
            @client.update_release(release["url"],
                                   body: metadata.to_release_body)
            PublishResult.new(tag: release["tag_name"],
                              url: release["html_url"], created?: false)
          end

          def upload_asset(release_id, artifact)
            @client.upload_asset(release_id, artifact.zip_path,
                                 content_type: "application/zip")
          end

          def delete_existing_release(tag_name)
            release = find_release(tag_name)
            @client.delete_release(release["url"]) if release
            begin
              @client.delete_ref(@repo, "tags/#{tag_name}")
            rescue StandardError
              nil
            end
          end
        end
      end
    end
  end
end
