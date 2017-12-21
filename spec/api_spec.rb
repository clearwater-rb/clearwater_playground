require 'route_helper'

require 'api'

RSpec.describe API do
  include APIHelper

  it 'does a thing' do
    header 'Content-Type', 'application/json'
    get '/playgrounds'

    expect(response).to be_ok, "Expected 200, got #{response.status}"
  end
end
