require 'bowser/http'
require 'grand_central'
require 'actions'

class AppState < GrandCentral::Model
  attributes(
    :playground_id,
    :name,
    :description,
    :html,
    :css,
    :ruby,
    :show_js,
    :errors,
  )

  alias show_js? show_js

  def js
    @js ||= Language.new(
      name: 'js',
      code: compile_js,
      show: show_js,
    )
  end

  def persisted?
    !!id
  end

  def compile_js
    start = Time.now
    Opal.compile(ruby.code.to_s).to_s
  rescue SyntaxError => e
    <<-JS
/*
#{e.message}
*/
    JS
  ensure
    finish = Time.now
    puts "Compiled (or errored) in #{(finish - start) * 1000}ms"
  end
end

class Language < GrandCentral::Model
  attributes :name, :code, :show

  def initialize *args
    super

    @show = false if show.nil?
  end

  alias show? show
end

class AppSerializer
  attr_reader :app

  def initialize app
    @app = app
  end

  # attributes :id, :html, :css, :ruby, :show_js
  def call
    {
      name: app.name,
      html: app.html.code,
      css: app.css.code,
      ruby: app.ruby.code,
    }
  end
end

initial_state = AppState.new(
  html: Language.new(
    name: 'html',
    code: <<-HTML,
<div id="app"></div>
    HTML
  ),
  css: Language.new(
    name: 'css',
    code: <<-CSS,
    CSS
  ),
  ruby: Language.new(
    name: 'ruby',
    code: <<-RUBY,
class Layout
  include Clearwater::Component

  def render
    div([
      h1('Hello World!'),
      p('Welcome to Clearwater!'),
    ])
  end
end

app = Clearwater::Application.new(
  component: Layout.new,
  element: Bowser.document['#app'],
)
app.call
    RUBY
    show: true,
  ),
  show_js: false,
  errors: [],
)

Store = GrandCentral::Store.new(initial_state) do |state, action|
  case action
  when UpdateCode
    new_state = state.update(
      action.language.name => action.language.update(
        code: action.code,
      ),
    )
  when SetPlaygroundName
    state.update(name: action.name)
  when ToggleEditor
    state.update(
      action.language.name => action.language.update(
        show: !action.language.show?,
      ),
    )
  when ToggleJS
    state.update show_js: !state.show_js?

  when LoadPlayground
    state.update(
      playground_id: action.id,
      name: action.name,
      html: state.html.update(code: action.html),
      css: state.css.update(code: action.css),
      ruby: state.ruby.update(code: action.ruby),
    )

  when SetError
    state.update(errors: state.errors + [action.error])
  when ClearErrors
    state.update(errors: [])
  when DeleteError
    state.update(errors: state.errors - [action.error])

  else
    state
  end
end

Store.on_dispatch do |before, after, action|
  case action
  when FetchPlayground
    Bowser::HTTP.fetch("/api/playgrounds/#{action.id}")
      .then(&:json)
      .then(&LoadPlayground)
      .catch { |e| warn e }
  when SavePlayground
    if before.playground_id
      Bowser::HTTP.fetch(
        "/api/playgrounds/#{before.playground_id}",
        method: :put,
        headers: { 'Content-Type': 'application/json' },
        data: { playground: AppSerializer.new(after).call },
      )
        .catch(&SetError)
    else
      Bowser::HTTP.fetch(
        '/api/playgrounds',
        method: :post,
        headers: { 'Content-Type': 'application/json' },
        data: { playground: AppSerializer.new(after).call },
      )
        .then(&:json)
        .then(&LoadPlayground)
        .then { |action| RedirectTo.call "/playgrounds/#{action.id}" }
        .catch { |e| warn e }
    end
  when RedirectTo
    Clearwater::Router.navigate_to action.path
  end
end

Action.store = Store
