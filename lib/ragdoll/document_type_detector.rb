# frozen_string_literal: true

module Ragdoll
  class DocumentTypeDetector
    SUPPORTED_TYPES = {
      '.txt' => 'text',
      '.md' => 'markdown',
      '.markdown' => 'markdown',
      '.pdf' => 'pdf',
      '.docx' => 'docx',
      '.doc' => 'doc',
      '.html' => 'html',
      '.htm' => 'html',
      '.json' => 'json',
      '.xml' => 'xml',
      '.csv' => 'csv',
      '.rtf' => 'rtf',
      '.odt' => 'odt'
    }.freeze

    PARSEABLE_TYPES = %w[text markdown pdf docx html json xml csv].freeze

    def self.detect(file_path)
      extension = File.extname(file_path).downcase
      SUPPORTED_TYPES[extension] || 'unknown'
    end

    def self.supported?(file_path)
      extension = File.extname(file_path).downcase
      SUPPORTED_TYPES.key?(extension)
    end

    def self.parseable?(file_path)
      document_type = detect(file_path)
      PARSEABLE_TYPES.include?(document_type)
    end

    def self.supported_extensions
      SUPPORTED_TYPES.keys
    end

    def self.parseable_types
      PARSEABLE_TYPES
    end

    # Get human-readable description
    def self.describe(file_path)
      document_type = detect(file_path)
      
      case document_type
      when 'text' then 'Plain Text'
      when 'markdown' then 'Markdown Document'
      when 'pdf' then 'PDF Document'
      when 'docx' then 'Microsoft Word Document'
      when 'doc' then 'Microsoft Word Document (Legacy)'
      when 'html' then 'HTML Document'
      when 'json' then 'JSON Data'
      when 'xml' then 'XML Document'
      when 'csv' then 'CSV Data'
      when 'rtf' then 'Rich Text Format'
      when 'odt' then 'OpenDocument Text'
      else 'Unknown Document Type'
      end
    end

    # Check if file contains text that can be meaningfully embedded
    def self.embeddable?(file_path)
      return false unless parseable?(file_path)
      return false unless File.exist?(file_path)
      
      # Check file size (avoid extremely large files)
      file_size = File.size(file_path)
      return false if file_size > 100.megabytes
      return false if file_size == 0

      # For text files, do a quick content check
      if %w[text markdown html json xml csv].include?(detect(file_path))
        begin
          sample = File.read(file_path, 1000) # Read first 1KB
          # Check if it's mostly text (not binary)
          return sample.valid_encoding? && sample.count("\x00") == 0
        rescue
          return false
        end
      end

      true
    end
  end
end