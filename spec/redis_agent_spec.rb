require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::RedisAgent do
  before(:each) do
    @valid_options = Agents::RedisAgent.new.default_options
    @checker = Agents::RedisAgent.new(:name => "RedisAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
