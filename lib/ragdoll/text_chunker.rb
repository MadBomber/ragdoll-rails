# frozen_string_literal: true

module Ragdoll
  class TextChunker
    DEFAULT_CHUNK_SIZE = 1000
    DEFAULT_CHUNK_OVERLAP = 200

    def self.chunk(text, chunk_size: DEFAULT_CHUNK_SIZE, chunk_overlap: DEFAULT_CHUNK_OVERLAP)
      new(text, chunk_size: chunk_size, chunk_overlap: chunk_overlap).chunk
    end

    def initialize(text, chunk_size: DEFAULT_CHUNK_SIZE, chunk_overlap: DEFAULT_CHUNK_OVERLAP)
      @text = text.to_s
      @chunk_size = chunk_size
      @chunk_overlap = chunk_overlap
    end

    def chunk
      return [] if @text.empty?
      return [@text] if @text.length <= @chunk_size

      chunks = []
      start_pos = 0

      while start_pos < @text.length
        end_pos = start_pos + @chunk_size

        # If this is the last chunk, take everything remaining
        if end_pos >= @text.length
          chunks << @text[start_pos..-1].strip
          break
        end

        # Try to find a good breaking point (sentence, paragraph, or word boundary)
        chunk_text = @text[start_pos...end_pos]
        break_pos = find_break_position(chunk_text, @text, start_pos, end_pos)

        # Extract the chunk
        actual_end_pos = start_pos + break_pos
        chunk_content = @text[start_pos...actual_end_pos].strip
        
        chunks << chunk_content unless chunk_content.empty?

        # Move to next chunk with overlap
        start_pos = actual_end_pos - @chunk_overlap
        start_pos = [start_pos, 0].max # Ensure we don't go negative
      end

      chunks.select { |chunk| !chunk.empty? }
    end

    private

    def find_break_position(chunk_text, full_text, start_pos, end_pos)
      # Priority order for breaking points:
      # 1. Double newline (paragraph break)
      # 2. Single newline + sentence ending
      # 3. Sentence ending punctuation
      # 4. Word boundary
      # 5. Character boundary (fallback)

      # Look for paragraph breaks
      paragraph_break = chunk_text.rindex("\n\n")
      if paragraph_break && paragraph_break > @chunk_size * 0.5
        return paragraph_break + 2
      end

      # Look for sentence endings near newlines
      sentence_patterns = [
        /[.!?]\s*\n/,
        /[.!?]\s+[A-Z]/,
        /[.!?]$/
      ]

      sentence_patterns.each do |pattern|
        matches = chunk_text.enum_for(:scan, pattern).map { Regexp.last_match.end(0) }
        if matches.any?
          # Find the best sentence break (closest to chunk_size but not too small)
          best_break = matches.select { |pos| pos > @chunk_size * 0.5 }.max
          return best_break if best_break
        end
      end

      # Look for word boundaries
      word_break = chunk_text.rindex(/\s/)
      if word_break && word_break > @chunk_size * 0.3
        return word_break + 1
      end

      # Fallback to character boundary
      @chunk_size
    end

    # Alternative chunking method for structured documents
    def self.chunk_by_structure(text, max_chunk_size: DEFAULT_CHUNK_SIZE)
      chunks = []
      current_chunk = ""

      # Split by paragraphs first
      paragraphs = text.split(/\n\s*\n/)

      paragraphs.each do |paragraph|
        paragraph = paragraph.strip
        next if paragraph.empty?

        # If adding this paragraph would exceed chunk size, start new chunk
        if !current_chunk.empty? && (current_chunk.length + paragraph.length + 2) > max_chunk_size
          chunks << current_chunk.strip
          current_chunk = ""
        end

        # If single paragraph is too large, split it
        if paragraph.length > max_chunk_size
          # Split large paragraph into sentences
          sentences = paragraph.split(/(?<=[.!?])\s+/)
          
          sentences.each do |sentence|
            sentence = sentence.strip
            next if sentence.empty?

            if !current_chunk.empty? && (current_chunk.length + sentence.length + 1) > max_chunk_size
              chunks << current_chunk.strip
              current_chunk = ""
            end

            if sentence.length > max_chunk_size
              # Split very long sentences by words
              words = sentence.split(/\s+/)
              words.each do |word|
                if !current_chunk.empty? && (current_chunk.length + word.length + 1) > max_chunk_size
                  chunks << current_chunk.strip
                  current_chunk = ""
                end
                current_chunk += (current_chunk.empty? ? "" : " ") + word
              end
            else
              current_chunk += (current_chunk.empty? ? "" : " ") + sentence
            end
          end
        else
          current_chunk += (current_chunk.empty? ? "" : "\n\n") + paragraph
        end
      end

      chunks << current_chunk.strip unless current_chunk.strip.empty?
      chunks.select { |chunk| !chunk.empty? }
    end

    # Specialized chunking for code documents
    def self.chunk_code(text, max_chunk_size: DEFAULT_CHUNK_SIZE)
      chunks = []
      current_chunk = ""

      # Split by functions, classes, or logical blocks
      lines = text.split("\n")
      current_block = []
      block_indent = nil

      lines.each do |line|
        line_indent = line[/^\s*/].length

        # Detect block boundaries (functions, classes, etc.)
        if line.match?(/^\s*(def|class|function|const|let|var)\s/) || 
           (block_indent && line_indent <= block_indent && !line.strip.empty?)
          
          # Process current block
          if current_block.any?
            block_text = current_block.join("\n")
            
            if !current_chunk.empty? && (current_chunk.length + block_text.length + 1) > max_chunk_size
              chunks << current_chunk.strip
              current_chunk = ""
            end
            
            current_chunk += (current_chunk.empty? ? "" : "\n") + block_text
          end

          current_block = [line]
          block_indent = line_indent
        else
          current_block << line
        end
      end

      # Process final block
      if current_block.any?
        block_text = current_block.join("\n")
        if !current_chunk.empty? && (current_chunk.length + block_text.length + 1) > max_chunk_size
          chunks << current_chunk.strip
          current_chunk = ""
        end
        current_chunk += (current_chunk.empty? ? "" : "\n") + block_text
      end

      chunks << current_chunk.strip unless current_chunk.strip.empty?
      chunks.select { |chunk| !chunk.empty? }
    end
  end
end