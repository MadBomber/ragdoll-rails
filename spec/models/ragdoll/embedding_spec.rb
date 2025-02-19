require 'rails_helper'

RSpec.describe Ragdoll::Embedding, type: :model do
  it { should belong_to(:document) }
end
