require 'bundler/setup'
require 'rack/test'
require 'roda'

module APIHelper
  include Rack::Test::Methods

  def app
    described_class
  end

  alias response last_response
end
