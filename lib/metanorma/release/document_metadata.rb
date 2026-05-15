# frozen_string_literal: true

module Metanorma
  module Release
    class DocumentMetadata
      attr_reader :id, :title, :version, :doctype, :document_type,
                  :flavor, :revdate, :source_path, :output_dir,
                  :formats, :file_base_name

      def initialize(id:, title:, version:, doctype:, document_type:,
                     flavor:, revdate:, source_path:, output_dir:,
                     formats:, file_base_name:)
        @id = id
        @title = title
        @version = version
        @doctype = doctype
        @document_type = document_type
        @flavor = flavor
        @revdate = revdate
        @source_path = source_path
        @output_dir = output_dir
        @formats = formats.freeze
        @file_base_name = file_base_name
        @lookup = {
          'id' => @id, 'title' => @title, 'doctype' => @doctype,
          'document_type' => @document_type, 'flavor' => @flavor,
          'revdate' => @revdate, 'source_path' => @source_path,
          'output_dir' => @output_dir, 'formats' => @formats,
          'file_base_name' => @file_base_name
        }.freeze
        freeze
      end

      def [](key)
        @lookup[key]
      end
    end
  end
end
