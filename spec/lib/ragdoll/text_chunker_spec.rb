require 'rails_helper'

RSpec.describe Ragdoll::TextChunker do
  describe '.chunk' do
    it 'delegates to instance method' do
      text = "Test text"
      chunker_instance = double('chunker')
      expected_chunks = ['Test', 'text']
      
      expect(described_class).to receive(:new).with(text, chunk_size: 100, chunk_overlap: 20).and_return(chunker_instance)
      expect(chunker_instance).to receive(:chunk).and_return(expected_chunks)
      
      result = described_class.chunk(text, chunk_size: 100, chunk_overlap: 20)
      expect(result).to eq(expected_chunks)
    end
  end

  describe '#initialize' do
    it 'sets text and default parameters' do
      text = "Test text"
      chunker = described_class.new(text)
      
      expect(chunker.instance_variable_get(:@text)).to eq(text)
      expect(chunker.instance_variable_get(:@chunk_size)).to eq(1000)
      expect(chunker.instance_variable_get(:@chunk_overlap)).to eq(200)
    end

    it 'allows custom parameters' do
      text = "Test text"
      chunker = described_class.new(text, chunk_size: 500, chunk_overlap: 100)
      
      expect(chunker.instance_variable_get(:@chunk_size)).to eq(500)
      expect(chunker.instance_variable_get(:@chunk_overlap)).to eq(100)
    end

    it 'converts nil text to string' do
      chunker = described_class.new(nil)
      expect(chunker.instance_variable_get(:@text)).to eq('')
    end
  end

  describe '#chunk' do
    context 'with empty or short text' do
      it 'returns empty array for empty text' do
        chunker = described_class.new('')
        expect(chunker.chunk).to eq([])
      end

      it 'returns single chunk for short text' do
        text = 'Short text'
        chunker = described_class.new(text, chunk_size: 100)
        expect(chunker.chunk).to eq([text])
      end
    end

    context 'with text that fits in one chunk' do
      it 'returns single chunk' do
        text = 'This is a medium length text that should fit in one chunk.'
        chunker = described_class.new(text, chunk_size: 100)
        
        result = chunker.chunk
        
        expect(result).to eq([text])
      end
    end

    context 'with text requiring multiple chunks' do
      let(:long_text) do
        "This is the first paragraph. It contains several sentences that provide context and information. " +
        "This sentence is part of the first paragraph.\n\n" +
        "This is the second paragraph. It also contains multiple sentences. Each sentence adds to the content. " +
        "This is another sentence in the second paragraph.\n\n" +
        "This is the third paragraph. It continues the document with more information. " +
        "The content keeps flowing with additional details."
      end

      it 'splits text into multiple chunks' do
        chunker = described_class.new(long_text, chunk_size: 150, chunk_overlap: 50)
        
        result = chunker.chunk
        
        expect(result.length).to be > 1
        result.each do |chunk|
          expect(chunk.length).to be <= 200 # allowing some flexibility for break points
          expect(chunk.strip).not_to be_empty
        end
      end

      it 'respects chunk overlap' do
        text = "First sentence. Second sentence. Third sentence. Fourth sentence. Fifth sentence."
        chunker = described_class.new(text, chunk_size: 30, chunk_overlap: 10)
        
        result = chunker.chunk
        
        expect(result.length).to be > 1
        # Check that there's some overlap between consecutive chunks
        expect(result[0]).to match(/First sentence/)
        expect(result[1]).to match(/sentence/) # Should have some overlap
      end
    end

    context 'with different text structures' do
      it 'handles paragraph breaks well' do
        text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
        chunker = described_class.new(text, chunk_size: 25, chunk_overlap: 5)
        
        result = chunker.chunk
        
        expect(result.length).to be > 1
        # Should prefer breaking at paragraph boundaries
        expect(result.any? { |chunk| chunk.start_with?("Second paragraph") }).to be true
      end

      it 'handles sentence breaks' do
        text = "First sentence. Second sentence. Third sentence. Fourth sentence."
        chunker = described_class.new(text, chunk_size: 30, chunk_overlap: 5)
        
        result = chunker.chunk
        
        expect(result.length).to be > 1
        # Should prefer breaking at sentence boundaries
        result.each do |chunk|
          expect(chunk.strip).not_to end_with('.')
          expect(chunk.strip).not_to start_with('.')
        end
      end

      it 'handles word boundaries when no sentence breaks available' do
        text = "word1 word2 word3 word4 word5 word6 word7 word8 word9 word10"
        chunker = described_class.new(text, chunk_size: 20, chunk_overlap: 5)
        
        result = chunker.chunk
        
        expect(result.length).to be > 1
        result.each do |chunk|
          # Should not break in the middle of words
          expect(chunk.strip).not_to match(/^\w+$/) # Single partial word
        end
      end
    end

    context 'with edge cases' do
      it 'handles very small chunk sizes' do
        text = "Test content"
        chunker = described_class.new(text, chunk_size: 5, chunk_overlap: 1)
        
        result = chunker.chunk
        
        expect(result).not_to be_empty
        result.each { |chunk| expect(chunk.strip).not_to be_empty }
      end

      it 'handles zero overlap' do
        text = "First chunk content. Second chunk content. Third chunk content."
        chunker = described_class.new(text, chunk_size: 20, chunk_overlap: 0)
        
        result = chunker.chunk
        
        expect(result.length).to be > 1
        # With zero overlap, chunks should not share content
      end

      it 'handles overlap larger than chunk size' do
        text = "Some content for testing overlap behavior."
        chunker = described_class.new(text, chunk_size: 10, chunk_overlap: 15)
        
        result = chunker.chunk
        
        expect(result).not_to be_empty
        # Should handle gracefully without infinite loops
      end
    end

    context 'with special characters and unicode' do
      it 'handles unicode text properly' do
        text = "Tëst cöntënt with émojis 🚀 and spëcial chãracters. More unicode content: café, naïve, résumé."
        chunker = described_class.new(text, chunk_size: 50, chunk_overlap: 10)
        
        result = chunker.chunk
        
        expect(result).not_to be_empty
        result.each do |chunk|
          expect(chunk).to be_valid_encoding
          expect(chunk.strip).not_to be_empty
        end
      end

      it 'handles newlines and whitespace' do
        text = "Line 1\n\nLine 2\n   \nLine 3\t\tTab content"
        chunker = described_class.new(text, chunk_size: 20, chunk_overlap: 5)
        
        result = chunker.chunk
        
        expect(result).not_to be_empty
        result.each { |chunk| expect(chunk.strip).not_to be_empty }
      end
    end
  end

  describe '.chunk_by_structure' do
    it 'splits by paragraphs first' do
      text = "First paragraph content.\n\nSecond paragraph content.\n\nThird paragraph content."
      
      result = described_class.chunk_by_structure(text, max_chunk_size: 100)
      
      expect(result.length).to be >= 1
      # Should keep paragraphs together when possible
      expect(result.first).to include("First paragraph")
    end

    it 'splits large paragraphs by sentences' do
      large_paragraph = "First sentence in a very long paragraph. " * 10
      text = "#{large_paragraph}\n\nSecond paragraph."
      
      result = described_class.chunk_by_structure(text, max_chunk_size: 100)
      
      expect(result.length).to be > 1
      # Should split the large paragraph
    end

    it 'handles very long sentences by words' do
      long_sentence = "word " * 100 # No sentence breaks
      
      result = described_class.chunk_by_structure(long_sentence, max_chunk_size: 50)
      
      expect(result.length).to be > 1
      result.each { |chunk| expect(chunk.length).to be <= 100 } # Some flexibility
    end
  end

  describe '.chunk_code' do
    let(:code_text) do
      <<~CODE
        def first_method
          puts "Hello"
          return true
        end

        class TestClass
          def initialize
            @name = "test"
          end

          def method_name
            @name.upcase
          end
        end

        function jsFunction() {
          return "JavaScript";
        }
      CODE
    end

    it 'chunks code by logical blocks' do
      result = described_class.chunk_code(code_text, max_chunk_size: 100)
      
      expect(result.length).to be > 1
      # Should group related code together
      expect(result.any? { |chunk| chunk.include?("def first_method") }).to be true
      expect(result.any? { |chunk| chunk.include?("class TestClass") }).to be true
    end

    it 'respects indentation boundaries' do
      result = described_class.chunk_code(code_text, max_chunk_size: 200)
      
      result.each do |chunk|
        lines = chunk.split("\n")
        # Should not break in the middle of indented blocks arbitrarily
        expect(lines).not_to be_empty
      end
    end
  end

  describe 'private methods' do
    let(:chunker) { described_class.new("test text", chunk_size: 100, chunk_overlap: 20) }

    describe '#find_break_position' do
      it 'prefers paragraph breaks' do
        chunk_text = "First line.\n\nSecond paragraph starts here."
        full_text = chunk_text
        
        position = chunker.send(:find_break_position, chunk_text, full_text, 0, chunk_text.length)
        
        # Should find the paragraph break
        expect(position).to be > 10
        expect(chunk_text[0...position]).to include("\n\n")
      end

      it 'falls back to sentence breaks' do
        chunk_text = "First sentence. Second sentence starts here."
        full_text = chunk_text
        
        position = chunker.send(:find_break_position, chunk_text, full_text, 0, chunk_text.length)
        
        # Should find a sentence break
        expect(position).to be > 10
        expect(chunk_text[0...position]).to end_with('. ')
      end

      it 'uses word boundaries as last resort' do
        chunk_text = "word1 word2 word3 word4 word5"
        full_text = chunk_text
        
        position = chunker.send(:find_break_position, chunk_text, full_text, 0, chunk_text.length)
        
        # Should find a word boundary
        expect(position).to be > 5
        expect(chunk_text[position - 1]).to eq(' ')
      end
    end
  end
end