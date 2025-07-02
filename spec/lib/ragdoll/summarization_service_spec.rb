require 'rails_helper'

RSpec.describe Ragdoll::SummarizationService do
  let(:mock_client) { double('ruby_llm_client') }
  let(:service) { described_class.new(client: mock_client) }

  describe '#initialize' do
    it 'configures RubyLLM when no client provided' do
      expect(RubyLLM).to receive(:configure)
      described_class.new
    end

    it 'uses provided client' do
      service = described_class.new(client: mock_client)
      expect(service.instance_variable_get(:@client)).to eq(mock_client)
    end
  end

  describe '#generate_summary' do
    let(:content) { "This is a test document with enough content to summarize. " * 20 }
    let(:mock_summary) { "This is a concise summary of the test document." }

    context 'with successful API response' do
      before do
        allow(mock_client).to receive(:chat).and_return({
          'choices' => [{ 'message' => { 'content' => mock_summary } }]
        })
      end

      it 'generates summary for content' do
        result = service.generate_summary(content)
        
        expect(result).to eq(mock_summary)
        expect(mock_client).to have_received(:chat).with(
          messages: anything,
          model: 'gpt-4',
          max_tokens: 300,
          temperature: 0.3
        )
      end

      it 'returns original content for very short text' do
        short_content = "Short text."
        result = service.generate_summary(short_content)
        
        expect(result).to eq(short_content)
        expect(mock_client).not_to have_received(:chat)
      end

      it 'cleans content before sending to API' do
        dirty_content = "  Text  with\n\n\nextra   whitespace\t\t  " * 50
        
        service.generate_summary(dirty_content)
        
        expect(mock_client).to have_received(:chat)
      end

      it 'truncates very long content' do
        long_content = "word " * 5000 # Very long content
        
        service.generate_summary(long_content)
        
        # Should truncate but still call the API
        expect(mock_client).to have_received(:chat)
      end

      it 'accepts custom options' do
        options = { model: 'gpt-3.5-turbo', max_tokens: 150 }
        
        service.generate_summary(content, options)
        
        expect(mock_client).to have_received(:chat).with(
          messages: anything,
          model: 'gpt-3.5-turbo',
          max_tokens: 150,
          temperature: 0.3
        )
      end
    end

    context 'with empty or nil content' do
      it 'returns nil for blank content' do
        expect(service.generate_summary(nil)).to be_nil
        expect(service.generate_summary("")).to be_nil
        expect(service.generate_summary("   ")).to be_nil
      end
    end

    context 'with API errors' do
      it 'raises SummarizationError for LLM provider errors' do
        allow(mock_client).to receive(:chat)
          .and_raise(RubyLLM::Error.new("LLM provider error"))
        
        expect {
          service.generate_summary(content)
        }.to raise_error(Ragdoll::SummarizationService::SummarizationError, /LLM provider error/)
      end

      it 'raises SummarizationError for network errors' do
        allow(mock_client).to receive(:chat)
          .and_raise(Faraday::Error.new("Network error"))
        
        expect {
          service.generate_summary(content)
        }.to raise_error(Ragdoll::SummarizationService::SummarizationError, /Network error/)
      end

      it 'raises SummarizationError for JSON parsing errors' do
        allow(mock_client).to receive(:chat)
          .and_raise(JSON::ParserError.new("Invalid JSON"))
        
        expect {
          service.generate_summary(content)
        }.to raise_error(Ragdoll::SummarizationService::SummarizationError, /Invalid JSON/)
      end

      it 'raises SummarizationError for other exceptions' do
        allow(mock_client).to receive(:chat)
          .and_raise(StandardError.new("Unknown error"))
        
        expect {
          service.generate_summary(content)
        }.to raise_error(Ragdoll::SummarizationService::SummarizationError, /Failed to generate summary/)
      end
    end
  end

  describe '#generate_document_summary' do
    let(:document) { create(:ragdoll_document, content: "Document content " * 100) }
    let(:mock_summary) { "Document summary" }

    before do
      allow(mock_client).to receive(:chat).and_return({
        'choices' => [{ 'message' => { 'content' => mock_summary } }]
      })
    end

    it 'generates summary for document' do
      result = service.generate_document_summary(document)
      
      expect(result).to eq(mock_summary)
      expect(mock_client).to have_received(:chat)
    end

    it 'returns nil for document without content' do
      document.update!(content: nil)
      result = service.generate_document_summary(document)
      
      expect(result).to be_nil
      expect(mock_client).not_to have_received(:chat)
    end

    it 'uses document metadata in prompt' do
      document.update!(
        title: "Test Document",
        document_type: "pdf"
      )
      
      service.generate_document_summary(document)
      
      # Verify the API was called with document context
      expect(mock_client).to have_received(:chat)
    end
  end

  describe 'private methods' do
    describe '#clean_content' do
      it 'normalizes whitespace' do
        dirty_content = "  Text   with\n\n\nextra\t\twhitespace  "
        
        cleaned = service.send(:clean_content, dirty_content)
        
        expect(cleaned).to eq("Text with\n\nextra whitespace")
      end

      it 'handles nil input' do
        expect(service.send(:clean_content, nil)).to eq('')
      end

      it 'truncates very long content' do
        long_content = "a" * 20000
        
        cleaned = service.send(:clean_content, long_content)
        
        expect(cleaned.length).to be <= 15000
        expect(cleaned).to include('[Content truncated for summarization]')
      end

      it 'preserves content shorter than limit' do
        short_content = "Short content"
        
        cleaned = service.send(:clean_content, short_content)
        
        expect(cleaned).to eq(short_content)
      end
    end

    describe '#determine_summary_length' do
      it 'returns appropriate length for content size' do
        expect(service.send(:determine_summary_length, "a" * 500)).to eq(100)
        expect(service.send(:determine_summary_length, "a" * 3000)).to eq(150)
        expect(service.send(:determine_summary_length, "a" * 7000)).to eq(200)
        expect(service.send(:determine_summary_length, "a" * 15000)).to eq(250)
        expect(service.send(:determine_summary_length, "a" * 25000)).to eq(300)
      end
    end

    describe '#build_system_prompt' do
      it 'creates document-type specific prompts' do
        pdf_prompt = service.send(:build_system_prompt, 'pdf', 200)
        code_prompt = service.send(:build_system_prompt, 'code', 200)
        
        expect(pdf_prompt).to include('document')
        expect(code_prompt).to include('code')
        expect(pdf_prompt).not_to eq(code_prompt)
      end
    end
  end

  describe 'integration with configuration' do
    it 'uses configured default model' do
      with_ragdoll_config(default_model: 'gpt-3.5-turbo') do
        allow(mock_client).to receive(:chat).and_return({
          'choices' => [{ 'message' => { 'content' => 'summary' } }]
        })
        
        service.generate_summary("content " * 100)
        
        expect(mock_client).to have_received(:chat).with(
          hash_including(model: 'gpt-3.5-turbo')
        )
      end
    end

    it 'respects configuration for summarization' do
      with_ragdoll_config(
        enable_document_summarization: true,
        summary_min_content_length: 500
      ) do
        expect(Ragdoll.configuration.enable_document_summarization).to be true
        expect(Ragdoll.configuration.summary_min_content_length).to eq(500)
      end
    end
  end

  describe 'response format handling' do
    it 'handles string responses' do
      allow(mock_client).to receive(:chat).and_return("Direct string response")
      
      result = service.generate_summary("content " * 100)
      
      expect(result).to eq("Direct string response")
    end

    it 'handles different hash response formats' do
      # Test OpenAI format
      allow(mock_client).to receive(:chat).and_return({
        'choices' => [{ 'message' => { 'content' => 'OpenAI format' } }]
      })
      
      result = service.generate_summary("content " * 100)
      expect(result).to eq("OpenAI format")
      
      # Test direct content format
      allow(mock_client).to receive(:chat).and_return({
        'content' => 'Direct content format'
      })
      
      result = service.generate_summary("content " * 100)
      expect(result).to eq("Direct content format")
      
      # Test message format
      allow(mock_client).to receive(:chat).and_return({
        'message' => { 'content' => 'Message format' }
      })
      
      result = service.generate_summary("content " * 100)
      expect(result).to eq("Message format")
    end

    it 'raises error for unrecognized response format' do
      allow(mock_client).to receive(:chat).and_return({
        'unknown_format' => 'data'
      })
      
      expect {
        service.generate_summary("content " * 100)
      }.to raise_error(Ragdoll::SummarizationService::SummarizationError, /Unable to extract summary/)
    end
  end
end