# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      module GitHub
        class TopicDiscoverer
          include Metanorma::Release::RepoDiscoverer

          def initialize(client:, organizations:, topic:)
            @client = client
            @organizations = organizations
            @topic = topic
          end

          def discover
            @organizations.flat_map do |org|
              query = "topic:#{@topic} org:#{org}"
              results = @client.search_repositories(query)
              results[:items].map do |repo|
                RepoRef.new(owner: org, repo: repo[:name])
              end
            end
          end
        end
      end
    end
  end
end
