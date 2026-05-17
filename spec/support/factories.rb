# frozen_string_literal: true

module Metanorma
  module Release
    module TestFactories
      def build_doc_id(raw = "CC 18011")
        DocumentId.from_raw(raw)
      end

      def build_channel(str = "public/standards")
        Channel.parse(str)
      end

      def build_repo_ref(owner: "CalConnect", repo: "cc-datetime-explicit")
        RepoRef.new(owner: owner, repo: repo)
      end
    end
  end
end

RSpec.configure do |config|
  config.include Metanorma::Release::TestFactories
end
