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
              all = []
              page = 1
              loop do
                results = @client.search_repositories(query, per_page: 100,
                                                      page: page)
                items = results[:items]
                break if items.nil? || items.empty?

                all.concat(items)
                break if items.length < 100

                page += 1
              end
              all.map do |repo|
                RepoRef.new(owner: org, repo: repo[:name])
              end
            end
          end
        end
      end
    end
  end
end
