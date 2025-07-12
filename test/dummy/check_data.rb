puts "Documents: #{Ragdoll::Document.count}"
puts "Embeddings: #{Ragdoll::Embedding.count}"
puts "Document contents that mention swagger:"
docs = Ragdoll::Document.where("content ILIKE ?", "%swagger%")
docs.each { |d| puts "- #{d.title}" }
puts "Sample embedding content:"
Ragdoll::Embedding.limit(3).each { |e| puts "- #{e.content[0..100]}..." }