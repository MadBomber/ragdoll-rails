puts "Debugging search functionality with no model filter..."

# Check configuration
puts "Ragdoll.configuration.embedding_model: #{Ragdoll.configuration&.embedding_model.inspect}"

# Test with no model filter
begin
  # Create embedding service directly
  service = Ragdoll::EmbeddingService.new
  
  # Generate dummy query embedding
  query_embedding = Array.new(1536) { rand(-1.0..1.0) }
  
  puts "Testing embedding service directly..."
  results = service.search_similar(
    query_embedding,
    {},
    limit: 10,
    threshold: 0.01,
    model_name: nil  # No model filter
  )
  
  puts "Direct service results: #{results.count}"
  
  if results.any?
    puts "Sample result:"
    result = results.first
    puts "  Similarity: #{result[:similarity]}"
    puts "  Content: #{result[:content][0..100]}..."
  else
    puts "No results found. Let's check what's happening..."
    
    # Check embeddings directly
    embeddings = Ragdoll::Embedding.joins(:document).limit(10)
    puts "Found #{embeddings.count} embeddings to process"
    
    embeddings.each_with_index do |embedding, i|
      puts "Embedding #{i+1}: model=#{embedding.model_name}, content_length=#{embedding.content&.length}"
      
      # Try to parse embedding
      begin
        parsed = JSON.parse(embedding.embedding)
        puts "  Parsed embedding length: #{parsed.length}"
        
        # Calculate similarity
        similarity = service.cosine_similarity(query_embedding, parsed)
        puts "  Similarity: #{similarity}"
      rescue => e
        puts "  Error parsing: #{e.message}"
      end
    end
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
end