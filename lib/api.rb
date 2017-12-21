require 'roda'
require 'primalize'

require 'models/playground'

class API < Roda
  plugin :json, classes: [Hash, Array, Primalize::Many]
  plugin :json_parser, parser: proc { |string| JSON.parse(string, symbolize_names: true) }
  plugin :empty_root
  plugin :all_verbs

  route do |r|
    r.on 'playgrounds' do
      r.on :app_id do |id|
        playground = Playground.find(id)

        r.get do
          PlaygroundResponse.new(playground: playground)
        end

        r.put do
          playground.update r.params[:playground]

          PlaygroundResponse.new(playground: playground)
        end
      end

      r.post do
        playground = Playground.new(r.params[:playground])

        if playground.save
          PlaygroundResponse.new(playground: playground)
        else
          PlaygroundErrorResponse.new(errors: playground.errors.to_a)
        end
      end

      PlaygroundsResponse.new(
        playgrounds: Playground.all,
      )
    end
  end

  class PlaygroundSerializer < Primalize::Single
    attributes(
      id: string,
      name: optional(string),
      html: string,
      css: string,
      ruby: string,
    )
  end

  class PlaygroundsResponse < Primalize::Many
    attributes(
      playgrounds: enumerable(PlaygroundSerializer),
    )
  end

  class PlaygroundResponse < Primalize::Many
    attributes(
      playground: PlaygroundSerializer,
    )
  end

  class ErrorSerializer < Primalize::Single
    attributes(message: string)
  end

  class ErrorResponse < Primalize::Many
    attributes(
      errors: enumerable(ErrorSerializer),
    )
  end
end
