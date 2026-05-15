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
        freeze
      end

      def [](key)
        case key
        when "id" then id
        when "title" then title
        when "doctype" then doctype
        when "document_type" then document_type
        when "flavor" then flavor
        when "revdate" then revdate
        when "source_path" then source_path
        when "output_dir" then output_dir
        when "formats" then formats
        when "file_base_name" then file_base_name
        else nil
        end
      end
    end
  end
end
