require 'rails_helper'

RSpec.describe Ragdoll::Document, type: :model do
  it { should have_many(:embeddings).dependent(:destroy) }
end
