# spec/tasks/ragdoll_spec.rb

require 'spec_helper'
describe Ragdoll do
  it "greets from Ragdoll" do
    expect { Ragdoll.new.invoke(:hello) }.to output(/Hello from the Ragdoll engine!/).to_stdout
  end
end
