require 'roda'
require 'app_repo'

class API < Roda
  plugin :json
  plugin :json_parser
  plugin :empty_root

  route do |r|
    r.on 'apps' do
      r.on :app_id do |id|
        app = AppRepo[id]

        r.get do
          {
            app: app,
          }
        end
      end

      r.post do
        p r.params
      end
    end
  end

  class App
    def initialize(id: nil, name:)
      @id = attrs[:id]
      @name = attrs[:name]
    end
  end
end
