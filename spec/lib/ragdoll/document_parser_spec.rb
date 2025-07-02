require 'rails_helper'

RSpec.describe Ragdoll::DocumentParser do
  describe '.parse' do
    it 'delegates to instance method' do
      file_path = create_test_text_file
      parser_instance = double('parser')
      result = { content: 'test', metadata: {}, document_type: 'text' }
      
      expect(described_class).to receive(:new).with(file_path).and_return(parser_instance)
      expect(parser_instance).to receive(:parse).and_return(result)
      
      expect(described_class.parse(file_path)).to eq(result)
      
      cleanup_test_files
    end
  end

  describe '#initialize' do
    it 'sets file path and extension' do
      parser = described_class.new('/path/to/file.pdf')
      
      expect(parser.instance_variable_get(:@file_path)).to eq('/path/to/file.pdf')
      expect(parser.instance_variable_get(:@file_extension)).to eq('.pdf')
    end

    it 'normalizes file extension to lowercase' do
      parser = described_class.new('/path/to/file.PDF')
      expect(parser.instance_variable_get(:@file_extension)).to eq('.pdf')
    end
  end

  describe '#parse' do
    context 'with text files' do
      it 'parses plain text files' do
        content = "This is a test document.\nWith multiple lines.\nAnd some content."
        file_path = create_test_text_file(content)
        
        result = described_class.parse(file_path)
        
        expect(result[:content]).to eq(content)
        expect(result[:document_type]).to eq('text')
        expect(result[:metadata]).to include(:file_size, :encoding)
        
        cleanup_test_files
      end

      it 'parses markdown files' do
        content = "# Test Document\n\nThis is **bold** text.\n\n- List item 1\n- List item 2"
        file_path = create_test_markdown_file(content)
        
        result = described_class.parse(file_path)
        
        expect(result[:content]).to eq(content)
        expect(result[:document_type]).to eq('markdown')
        expect(result[:metadata]).to include(:file_size, :encoding)
        
        cleanup_test_files
      end

      it 'handles encoding issues gracefully' do
        # Create a file with invalid UTF-8
        file_path = Rails.root.join('tmp', 'test_encoding.txt')
        File.write(file_path, "Valid text\x80Invalid UTF-8", encoding: 'ASCII-8BIT')
        
        result = described_class.parse(file_path.to_s)
        
        expect(result[:content]).to be_a(String)
        expect(result[:metadata][:encoding]).to eq('ISO-8859-1')
        
        File.delete(file_path) if File.exist?(file_path)
      end
    end

    context 'with HTML files' do
      it 'parses HTML and strips tags' do
        html_content = <<~HTML
          <html>
            <head><title>Test Page</title></head>
            <body>
              <h1>Main Heading</h1>
              <p>This is a paragraph with <strong>bold</strong> text.</p>
              <script>alert('remove me');</script>
              <style>body { color: red; }</style>
            </body>
          </html>
        HTML
        
        file_path = Rails.root.join('tmp', 'test.html')
        File.write(file_path, html_content)
        
        result = described_class.parse(file_path.to_s)
        
        expect(result[:content]).to include('Main Heading')
        expect(result[:content]).to include('This is a paragraph')
        expect(result[:content]).to include('bold')
        expect(result[:content]).not_to include('<h1>')
        expect(result[:content]).not_to include('alert')
        expect(result[:content]).not_to include('color: red')
        expect(result[:document_type]).to eq('html')
        
        File.delete(file_path) if File.exist?(file_path)
      end
    end

    context 'with JSON files' do
      it 'parses JSON files as text' do
        data = { title: 'Test Document', content: 'JSON content', tags: ['test', 'json'] }
        file_path = create_test_json_file(data)
        
        result = described_class.parse(file_path)
        
        expect(result[:content]).to eq(data.to_json)
        expect(result[:document_type]).to eq('json')
        
        cleanup_test_files
      end
    end

    context 'with PDF files (mocked)' do
      it 'parses PDF files and extracts text and metadata' do
        file_path = '/tmp/test.pdf'
        
        # Mock PDF::Reader
        mock_reader = double('pdf_reader')
        mock_info = {
          Title: 'Test PDF',
          Author: 'Test Author',
          Subject: 'Test Subject',
          CreationDate: Time.current
        }
        mock_page1 = double('page1', text: 'Page 1 content')
        mock_page2 = double('page2', text: 'Page 2 content')
        
        expect(PDF::Reader).to receive(:open).with(file_path).and_yield(mock_reader)
        expect(mock_reader).to receive(:info).and_return(mock_info).at_least(:once)
        expect(mock_reader).to receive(:page_count).and_return(2)
        expect(mock_reader).to receive(:pages).and_return([mock_page1, mock_page2])
        
        result = described_class.parse(file_path)
        
        expect(result[:content]).to include('Page 1 content')
        expect(result[:content]).to include('Page 2 content')
        expect(result[:document_type]).to eq('pdf')
        expect(result[:metadata][:title]).to eq('Test PDF')
        expect(result[:metadata][:author]).to eq('Test Author')
        expect(result[:metadata][:page_count]).to eq(2)
      end

      it 'handles malformed PDF files' do
        file_path = '/tmp/malformed.pdf'
        
        expect(PDF::Reader).to receive(:open).with(file_path)
          .and_raise(PDF::Reader::MalformedPDFError.new('Invalid PDF'))
        
        expect {
          described_class.parse(file_path)
        }.to raise_error(Ragdoll::DocumentParser::ParseError, /Malformed PDF/)
      end
    end

    context 'with DOCX files (mocked)' do
      it 'parses DOCX files and extracts content and metadata' do
        file_path = '/tmp/test.docx'
        
        # Mock Docx::Document
        mock_doc = double('docx_document')
        mock_properties = double('core_properties',
          title: 'Test DOCX',
          creator: 'Test Author',
          subject: 'Test Subject',
          created: Time.current
        )
        mock_paragraph1 = double('paragraph1', text: 'First paragraph')
        mock_paragraph2 = double('paragraph2', text: 'Second paragraph')
        mock_table = double('table')
        mock_row = double('row')
        mock_cell1 = double('cell1', text: 'Cell 1')
        mock_cell2 = double('cell2', text: 'Cell 2')
        
        expect(Docx::Document).to receive(:open).with(file_path).and_return(mock_doc)
        expect(mock_doc).to receive(:core_properties).and_return(mock_properties).at_least(:once)
        expect(mock_doc).to receive(:paragraphs).and_return([mock_paragraph1, mock_paragraph2])
        expect(mock_doc).to receive(:tables).and_return([mock_table])
        expect(mock_table).to receive(:rows).and_return([mock_row])
        expect(mock_row).to receive(:cells).and_return([mock_cell1, mock_cell2])
        
        result = described_class.parse(file_path)
        
        expect(result[:content]).to include('First paragraph')
        expect(result[:content]).to include('Second paragraph')
        expect(result[:content]).to include('Cell 1 | Cell 2')
        expect(result[:document_type]).to eq('docx')
        expect(result[:metadata][:title]).to eq('Test DOCX')
        expect(result[:metadata][:author]).to eq('Test Author')
        expect(result[:metadata][:paragraph_count]).to eq(2)
        expect(result[:metadata][:table_count]).to eq(1)
      end

      it 'handles DOCX parsing errors' do
        file_path = '/tmp/corrupted.docx'
        
        expect(Docx::Document).to receive(:open).with(file_path)
          .and_raise(StandardError.new('Corrupted file'))
        
        expect {
          described_class.parse(file_path)
        }.to raise_error(Ragdoll::DocumentParser::ParseError, /Failed to parse DOCX/)
      end
    end

    context 'with unsupported file types' do
      it 'falls back to text parsing for unknown extensions' do
        content = "Unknown file type content"
        file_path = Rails.root.join('tmp', 'test.unknown')
        File.write(file_path, content)
        
        result = described_class.parse(file_path.to_s)
        
        expect(result[:content]).to eq(content)
        expect(result[:document_type]).to eq('text')
        
        File.delete(file_path) if File.exist?(file_path)
      end
    end

    context 'error handling' do
      it 'raises ParseError for general failures' do
        file_path = '/nonexistent/file.txt'
        
        expect {
          described_class.parse(file_path)
        }.to raise_error(Ragdoll::DocumentParser::ParseError, /Failed to parse/)
      end

      it 'wraps specific exceptions in ParseError' do
        file_path = create_test_text_file
        
        allow(File).to receive(:read).and_raise(StandardError.new('Read error'))
        
        expect {
          described_class.parse(file_path)
        }.to raise_error(Ragdoll::DocumentParser::ParseError, /Failed to parse.*Read error/)
        
        cleanup_test_files
      end
    end
  end

  describe 'private methods' do
    let(:parser) { described_class.new('/tmp/test.txt') }

    describe '#parse_text' do
      it 'reads file content with UTF-8 encoding' do
        content = "Test content with unicode: émojis 🎉"
        file_path = create_test_text_file(content)
        parser = described_class.new(file_path)
        
        result = parser.send(:parse_text)
        
        expect(result[:content]).to eq(content)
        expect(result[:metadata][:encoding]).to eq('UTF-8')
        
        cleanup_test_files
      end

      it 'falls back to ISO-8859-1 for encoding issues' do
        file_path = Rails.root.join('tmp', 'test_iso.txt')
        File.write(file_path, "Content\x80", encoding: 'ASCII-8BIT')
        parser = described_class.new(file_path.to_s)
        
        result = parser.send(:parse_text)
        
        expect(result[:content]).to be_a(String)
        expect(result[:metadata][:encoding]).to eq('ISO-8859-1')
        
        File.delete(file_path) if File.exist?(file_path)
      end
    end

    describe '#parse_html' do
      it 'removes script and style tags' do
        html = '<html><script>bad();</script><style>css</style><p>good</p></html>'
        file_path = Rails.root.join('tmp', 'test.html')
        File.write(file_path, html)
        parser = described_class.new(file_path.to_s)
        
        result = parser.send(:parse_html)
        
        expect(result[:content]).to include('good')
        expect(result[:content]).not_to include('bad()')
        expect(result[:content]).not_to include('css')
        
        File.delete(file_path) if File.exist?(file_path)
      end
    end
  end
end