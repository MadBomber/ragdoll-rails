puts "Testing search functionality..."

begin
  client = Ragdoll::Client.new
  puts "Client created successfully"
  
  query = "swagger"
  puts "Searching for: #{query}"
  
  search_options = {
    limit: 10,
    threshold: 0.7,
    use_usage_ranking: false
  }
  
  search_response = client.search(query, **search_options)
  puts "Search response type: #{search_response.class}"
  puts "Search response: #{search_response.inspect}"
  
  results = search_response.is_a?(Hash) ? search_response[:results] || search_response["results"] || [] : []
  puts "Results count: #{results.count}"
  
  if results.any?
    puts "Sample result: #{results.first.inspect}"
  else
    puts "No results found"
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
end