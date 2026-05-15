# frozen_string_literal: true

require "rake"
require "ostruct"

module Metanorma
  module Release
    class RakeTasks
      include Rake::DSL

      def self.install(&block)
        new(&block).install
      end

      def initialize(&block)
        @config = OpenStruct.new(
          output_dir: "_site",
          manifest: "metanorma.release.yml",
          platform: "github",
          concurrency: 4,
          dest: "dist",
          source: "github",
          organizations: [],
          topic: "metanorma-release"
        )
        block.call(@config) if block
      end

      def install
        install_package_task
        install_publish_task
        install_aggregate_task
      end

      private

      def install_package_task
        desc "Package compiled documents"
        task :"mn:package" do
          argv = ["--output-dir", @config.output_dir,
                  "--dest", @config.dest,
                  "--manifest", @config.manifest]
          CLI.run_package(argv)
        end
      end

      def install_publish_task
        desc "Package and publish documents"
        task :"mn:publish" do
          argv = ["--platform", @config.platform,
                  "--output-dir", @config.output_dir,
                  "--manifest", @config.manifest,
                  "--concurrency", @config.concurrency.to_s]
          CLI.run_publish(argv)
        end
      end

      def install_aggregate_task
        desc "Aggregate released documents"
        task :"mn:aggregate" do
          argv = ["--source", @config.source,
                  "--output-dir", @config.output_dir,
                  "--concurrency", @config.concurrency.to_s]
          if @config.organizations.any?
            argv += ["--organizations", @config.organizations.join(",")]
          end
          argv += ["--topic", @config.topic] if @config.topic
          CLI.run_aggregate(argv)
        end
      end
    end
  end
end
