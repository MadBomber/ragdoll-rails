require 'rails_helper'

RSpec.describe Ragdoll::DocumentTypeDetector do
  describe '.detect' do
    it 'detects text files' do
      expect(described_class.detect('/path/file.txt')).to eq('text')
    end

    it 'detects markdown files' do
      expect(described_class.detect('/path/file.md')).to eq('markdown')
      expect(described_class.detect('/path/file.markdown')).to eq('markdown')
    end

    it 'detects PDF files' do
      expect(described_class.detect('/path/file.pdf')).to eq('pdf')
      expect(described_class.detect('/path/FILE.PDF')).to eq('pdf') # Case insensitive
    end

    it 'detects DOCX files' do
      expect(described_class.detect('/path/file.docx')).to eq('docx')
    end

    it 'detects HTML files' do
      expect(described_class.detect('/path/file.html')).to eq('html')
      expect(described_class.detect('/path/file.htm')).to eq('html')
    end

    it 'detects JSON files' do
      expect(described_class.detect('/path/file.json')).to eq('json')
    end

    it 'detects XML files' do
      expect(described_class.detect('/path/file.xml')).to eq('xml')
    end

    it 'detects CSV files' do
      expect(described_class.detect('/path/file.csv')).to eq('csv')
    end

    it 'detects legacy document formats' do
      expect(described_class.detect('/path/file.doc')).to eq('doc')
      expect(described_class.detect('/path/file.rtf')).to eq('rtf')
      expect(described_class.detect('/path/file.odt')).to eq('odt')
    end

    it 'returns unknown for unsupported extensions' do
      expect(described_class.detect('/path/file.exe')).to eq('unknown')
      expect(described_class.detect('/path/file.jpg')).to eq('unknown')
      expect(described_class.detect('/path/file')).to eq('unknown') # No extension
    end

    it 'handles case insensitive extensions' do
      expect(described_class.detect('/path/file.TXT')).to eq('text')
      expect(described_class.detect('/path/file.DOCX')).to eq('docx')
    end
  end

  describe '.supported?' do
    it 'returns true for supported file types' do
      supported_files = %w[
        /path/file.txt /path/file.md /path/file.pdf
        /path/file.docx /path/file.html /path/file.json
        /path/file.xml /path/file.csv /path/file.doc
        /path/file.rtf /path/file.odt
      ]

      supported_files.each do |file_path|
        expect(described_class.supported?(file_path)).to be true
      end
    end

    it 'returns false for unsupported file types' do
      unsupported_files = %w[
        /path/file.exe /path/file.jpg /path/file.mp3
        /path/file.bin /path/file.unknown /path/file
      ]

      unsupported_files.each do |file_path|
        expect(described_class.supported?(file_path)).to be false
      end
    end
  end

  describe '.parseable?' do
    it 'returns true for parseable document types' do
      parseable_files = %w[
        /path/file.txt /path/file.md /path/file.pdf
        /path/file.docx /path/file.html /path/file.json
        /path/file.xml /path/file.csv
      ]

      parseable_files.each do |file_path|
        expect(described_class.parseable?(file_path)).to be true
      end
    end

    it 'returns false for non-parseable document types' do
      non_parseable_files = %w[
        /path/file.doc /path/file.rtf /path/file.odt
        /path/file.exe /path/file.jpg
      ]

      non_parseable_files.each do |file_path|
        expect(described_class.parseable?(file_path)).to be false
      end
    end
  end

  describe '.supported_extensions' do
    it 'returns array of supported extensions' do
      extensions = described_class.supported_extensions
      
      expect(extensions).to be_an(Array)
      expect(extensions).to include('.txt', '.pdf', '.docx', '.html', '.json')
      expect(extensions).to all(start_with('.'))
    end
  end

  describe '.parseable_types' do
    it 'returns array of parseable document types' do
      types = described_class.parseable_types
      
      expect(types).to be_an(Array)
      expect(types).to include('text', 'pdf', 'docx', 'html', 'json')
      expect(types).not_to include('doc', 'rtf', 'odt') # Legacy formats
    end
  end

  describe '.describe' do
    it 'returns human-readable descriptions' do
      descriptions = {
        '/path/file.txt' => 'Plain Text',
        '/path/file.md' => 'Markdown Document',
        '/path/file.pdf' => 'PDF Document',
        '/path/file.docx' => 'Microsoft Word Document',
        '/path/file.doc' => 'Microsoft Word Document (Legacy)',
        '/path/file.html' => 'HTML Document',
        '/path/file.json' => 'JSON Data',
        '/path/file.xml' => 'XML Document',
        '/path/file.csv' => 'CSV Data',
        '/path/file.rtf' => 'Rich Text Format',
        '/path/file.odt' => 'OpenDocument Text',
        '/path/file.unknown' => 'Unknown Document Type'
      }

      descriptions.each do |file_path, expected_description|
        expect(described_class.describe(file_path)).to eq(expected_description)
      end
    end
  end

  describe '.embeddable?' do
    context 'with valid files' do
      let(:text_file) { create_test_text_file("Embeddable content") }
      let(:markdown_file) { create_test_markdown_file("# Embeddable markdown") }
      let(:json_file) { create_test_json_file({ content: "Embeddable JSON" }) }

      after { cleanup_test_files }

      it 'returns true for parseable files with valid content' do
        expect(described_class.embeddable?(text_file)).to be true
        expect(described_class.embeddable?(markdown_file)).to be true
        expect(described_class.embeddable?(json_file)).to be true
      end
    end

    context 'with non-parseable file types' do
      it 'returns false for non-parseable extensions' do
        expect(described_class.embeddable?('/path/file.doc')).to be false
        expect(described_class.embeddable?('/path/file.exe')).to be false
        expect(described_class.embeddable?('/path/file.jpg')).to be false
      end
    end

    context 'with file system issues' do
      it 'returns false for non-existent files' do
        expect(described_class.embeddable?('/nonexistent/file.txt')).to be false
      end

      it 'returns false for empty files' do
        empty_file = Rails.root.join('tmp', 'empty.txt')
        File.write(empty_file, '')
        
        expect(described_class.embeddable?(empty_file.to_s)).to be false
        
        File.delete(empty_file) if File.exist?(empty_file)
      end

      it 'returns false for very large files' do
        allow(File).to receive(:size).and_return(200.megabytes)
        
        expect(described_class.embeddable?('/path/huge.txt')).to be false
      end
    end

    context 'with text file content validation' do
      it 'returns true for valid text content' do
        valid_file = Rails.root.join('tmp', 'valid.txt')
        File.write(valid_file, 'Valid text content without null bytes')
        
        expect(described_class.embeddable?(valid_file.to_s)).to be true
        
        File.delete(valid_file) if File.exist?(valid_file)
      end

      it 'returns false for binary content with null bytes' do
        binary_file = Rails.root.join('tmp', 'binary.txt')
        File.write(binary_file, "Text with\x00null bytes", encoding: 'ASCII-8BIT')
        
        expect(described_class.embeddable?(binary_file.to_s)).to be false
        
        File.delete(binary_file) if File.exist?(binary_file)
      end

      it 'returns false for invalid encoding' do
        invalid_file = Rails.root.join('tmp', 'invalid.txt')
        File.write(invalid_file, "\x80\x81\x82", encoding: 'ASCII-8BIT')
        
        expect(described_class.embeddable?(invalid_file.to_s)).to be false
        
        File.delete(invalid_file) if File.exist?(invalid_file)
      end

      it 'handles file read errors gracefully' do
        file_path = '/path/protected.txt'
        allow(File).to receive(:exist?).with(file_path).and_return(true)
        allow(File).to receive(:size).with(file_path).and_return(1000)
        allow(File).to receive(:read).with(file_path, 1000)
          .and_raise(Errno::EACCES.new("Permission denied"))
        
        expect(described_class.embeddable?(file_path)).to be false
      end
    end

    context 'with PDF and DOCX files (mocked)' do
      it 'returns true for PDF files (assumes they are embeddable)' do
        pdf_path = '/path/document.pdf'
        allow(File).to receive(:exist?).with(pdf_path).and_return(true)
        allow(File).to receive(:size).with(pdf_path).and_return(1.megabyte)
        
        expect(described_class.embeddable?(pdf_path)).to be true
      end

      it 'returns true for DOCX files (assumes they are embeddable)' do
        docx_path = '/path/document.docx'
        allow(File).to receive(:exist?).with(docx_path).and_return(true)
        allow(File).to receive(:size).with(docx_path).and_return(500.kilobytes)
        
        expect(described_class.embeddable?(docx_path)).to be true
      end
    end
  end

  describe 'constants' do
    describe 'SUPPORTED_TYPES' do
      it 'maps extensions to document types' do
        expect(described_class::SUPPORTED_TYPES).to be_a(Hash)
        expect(described_class::SUPPORTED_TYPES['.txt']).to eq('text')
        expect(described_class::SUPPORTED_TYPES['.pdf']).to eq('pdf')
        expect(described_class::SUPPORTED_TYPES['.docx']).to eq('docx')
      end

      it 'is frozen to prevent modification' do
        expect(described_class::SUPPORTED_TYPES).to be_frozen
      end
    end

    describe 'PARSEABLE_TYPES' do
      it 'contains only parseable document types' do
        expect(described_class::PARSEABLE_TYPES).to be_an(Array)
        expect(described_class::PARSEABLE_TYPES).to include('text', 'pdf', 'docx')
        expect(described_class::PARSEABLE_TYPES).not_to include('doc', 'rtf')
      end

      it 'is frozen to prevent modification' do
        expect(described_class::PARSEABLE_TYPES).to be_frozen
      end
    end
  end

  describe 'edge cases' do
    it 'handles files with multiple dots in name' do
      expect(described_class.detect('/path/file.backup.txt')).to eq('text')
      expect(described_class.detect('/path/data.2023.json')).to eq('json')
    end

    it 'handles files with no extension' do
      expect(described_class.detect('/path/README')).to eq('unknown')
      expect(described_class.detect('/path/Makefile')).to eq('unknown')
    end

    it 'handles files starting with dots' do
      expect(described_class.detect('/path/.hidden.txt')).to eq('text')
      expect(described_class.detect('/path/.env')).to eq('unknown')
    end

    it 'handles empty file paths' do
      expect(described_class.detect('')).to eq('unknown')
      expect(described_class.detect(nil)).to eq('unknown')
    end
  end
end