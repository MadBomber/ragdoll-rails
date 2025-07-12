puts "Debugging search functionality..."

# Check what embeddings exist
puts "Total embeddings: #{Ragdoll::Embedding.count}"
puts "Embeddings by model:"
Ragdoll::Embedding.group(:model_name).count.each { |model, count| puts "  #{model}: #{count}" }

# Test with a lower threshold
begin
  client = Ragdoll::Client.new
  puts "\nTesting with lower threshold (0.1)..."
  
  query = "swagger"
  search_options = {
    limit: 10,
    threshold: 0.1,  # Much lower threshold
    use_usage_ranking: false
  }
  
  search_response = client.search(query, **search_options)
  puts "Results with threshold 0.1: #{search_response[:results].count}"
  
  if search_response[:results].any?
    puts "Sample result:"
    result = search_response[:results].first
    puts "  Similarity: #{result[:similarity]}"
    puts "  Content: #{result[:content][0..100]}..."
  end
  
  # Test with even lower threshold
  puts "\nTesting with threshold 0.01..."
  search_options[:threshold] = 0.01
  search_response = client.search(query, **search_options)
  puts "Results with threshold 0.01: #{search_response[:results].count}"
  
rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end