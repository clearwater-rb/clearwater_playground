require 'opal'
require 'clearwater'
require 'grand_central'
require 'forwardable'
require 'opal/compiler'
require 'clearwater/black_box_node'

class Layout
  include Clearwater::Component
  extend Forwardable

  delegate %w(html css ruby js) => :state

  attr_reader :store

  def initialize(store)
    @store = store
  end

  def render
    div([
      Header.new(html, css, ruby),
      CodeEditor.new(html, css, ruby, js),
      RunningExample.new(html, css, js),
    ])
  end

  def state
    store.state
  end
end

class Header
  include Clearwater::Component

  attr_reader :html, :css, :ruby

  def initialize html, css, ruby
    @html = html
    @css = css
    @ruby = ruby
  end

  def render
    div([
      h1({
        style: {
          'font-size': '2.5vh',
          font_family: [
            'Helvetica Neue',
            'Sans-Serif',
          ],
          height: '3vh',
        },
      }, [
        'Clearwater Playground',
      ]),
      div([
        [html, css, ruby].map { |lang|
          button({ onclick: ToggleEditor[lang] }, "Toggle #{lang.name}")
        },
        button({ onclick: ToggleJS }, 'Toggle compiled JS'),
      ]),
    ])
  end
end

class CodeEditor
  include Clearwater::Component

  attr_reader :html, :css, :ruby, :js

  def initialize(html, css, ruby, js)
    @html, @css, @ruby, @js = html, css, ruby, js
  end

  def render
    div({ style: Style.editor_container }, [
      [html, css, ruby].map { |lang|
        if lang.show?
          div({ style: Style.editor(total_editors) }, [
            AceEditor.new(lang)
          ])
        end
      },
      if js.show?
        div({ style: Style.editor(total_editors) }, [
          Editor.new(js)
        ])
      end,
    ])
  end

  def total_editors
    [html, css, ruby, js].count(&:show?)
  end

  module Style
    module_function

    def editor_container
      {
        display: 'inline-block',
        box_sizing: 'border-box',
        vertical_align: :top,
        width: '50%',
      }
    end

    def editor(total_editors=1)
      {
        height: "#{90 / [total_editors, 1].max}vh",
        vertical_align: :top,
      }
    end
  end
end

class AceEditor
  include Clearwater::BlackBoxNode

  attr_reader :editor, :height

  def initialize lang
    @lang = lang
    @id = lang.name
    @code = lang.code
  end

  def key
    @id
  end

  def node
    Clearwater::Component.div({
      id: @lang.name,
      style: {
        height: '100%',
        font_size: '16px',
      },
    }, @code)
  end

  def mount element
    Bowser.window.animation_frame do
      @editor = `ace.edit(#@id)`
      @editor.JS.setTheme 'ace/theme/monokai'
      @editor.JS.getSession.JS.setTabSize 2
      @editor.JS.getSession.JS.setMode "ace/mode/#@id"
      @editor.JS.on(:change, proc { |e|
        UpdateCode[@lang].call `#@editor.getSession().getDocument().getValue()`
      })
      @height = element.client_height
    end
  end

  def update previous, element
    # Copy properties from previous instance
    @editor = previous.editor
    @height = previous.height

    Bowser.window.animation_frame do
      # If they're different, tell the editor
      if @height != element.client_height
        @height = element.client_height
        @editor.JS.resize
      end
    end
  end
end

class Editor
  include Clearwater::Component

  def initialize lang
    @lang = lang
  end

  def render
    textarea(
      placeholder: @lang.name,
      value: @lang.code,
      oninput: UpdateCode[@lang],
      onkeydown: method(:check_key),
      style: {
        font_size: '14px',
        font_family: ['Monaco', 'Menlo', 'Courier New', 'Monospace'],
        width: '99%',
        height: '100%',
      },
    )
  end

  def check_key event
    input = event.target

    case event.key
    when :Backspace
      if input.selection_start == input.selection_end # Nothing selected
        code = @lang.code
        cursor_position = input.selection_start
        if code[cursor_position - 2...cursor_position] == '  '
          event.prevent

          UpdateCode.(@lang, "#{code[0...cursor_position - 2]}#{code[cursor_position..-1]}")
          Bowser.window.animation_frame do
            input.selection_start = cursor_position - 2
            input.selection_end = cursor_position - 2
          end
        end
      end
    when :Tab
      event.prevent
      code = @lang.code
      cursor_position = input.selection_start
      tab = '  '

      UpdateCode.(@lang, "#{code[0...cursor_position]}#{tab}#{code[cursor_position..-1]}")
      Bowser.window.animation_frame do
        input.selection_start = cursor_position + 2
        input.selection_end = cursor_position + 2
      end
    when :Enter
      event.prevent
      code = @lang.code
      cursor_position = input.selection_start
      space_count = 0
      i = 0
      while (char = input.value[cursor_position - i - 1]) != "\n"
        if char == ' '
          space_count += 1
        else
          space_count = 0
        end
        i += 1
      end

      indent_newline = "\n" + (' ' * space_count)
      UpdateCode.(@lang, "#{code[0...cursor_position]}#{indent_newline}#{code[cursor_position..-1]}")
      Bowser.window.animation_frame do
        input.selection_start = cursor_position + space_count + 1
        input.selection_end   = cursor_position + space_count + 1
      end
    end
  end
end

class RunningExample
  include Clearwater::Component
  include Clearwater::BlackBoxNode

  attr_reader :rendered_at
  attr_accessor :will_render

  def initialize html, css, js
    @html, @css, @js = html, css, js
    @will_render = true
  end

  def node
    iframe(
      srcdoc: srcdoc,
      style: {
        box_sizing: 'border-box',
        display: 'inline-block',
        vertical_align: :top,
        width: '50%',
        height: '90vh'
      },
    )
  end

  def mount node
    @rendered_at = Time.now
    @will_render = false
  end

  def update previous, node
    previous.will_render = false

    if Time.now - previous.rendered_at < 600 # cap an iframe to be 10 minutes old
      # Throttle running-code updates to 1 per second. Otherwise, we just spend
      # a ton of CPU time rebooting iframes.
      Bowser.window.delay 1 do
        node.srcdoc = srcdoc if will_render && srcdoc != previous.srcdoc
        @will_render = false
      end
      @rendered_at = previous.rendered_at
    else
      @rendered_at = Time.now
      render.create_element
    end
  end

  def srcdoc
    <<-HTML
<!DOCTYPE html>
<style>#{@css.code}</style>
#{@html.code}
<div id="js-error-container" style='background-color: darkred; color: #f99; position: absolute; bottom: 0; left: 0; right: 0; overflow: scroll;'></div>
<div id="ruby-error-container" style='background-color: darkred; color: #f99; position: absolute; bottom: 0; left: 0; right: 0; overflow: scroll;'></div>
<script src="/playground_boilerplate.js"></script>
<script>
  #{patch_clearwater}
  try {
    var jsErrorContainer = document.getElementById('js-error-container');
    jsErrorContainer.innerText = '';
    #{@js.code}
  } catch(e) {
    jsErrorContainer.innerText = e.name + ' - ' + e.message;
  }
</script>
      HTML
  end

  def patch_clearwater
    Opal.compile <<-RUBY
      module Clearwater
        class Application
          def perform_render
            if element.nil?
              raise TypeError, "Cannot render to a non-existent element. Make sure the document ready event has been triggered before invoking the application."
            end

            %x{
              try {
                var rendered = Opal.Clearwater.$const_get('Component').$sanitize_content(self.component.$render());
                self.$virtual_dom().$render(rendered);
              } catch(e) {
                console.error(e);
                jsErrorContainer.innerText = [e.name, e.message].$join(' - ');
              }
            }

            @will_render = false
            run_callbacks
            nil
          end
        end
      end
    RUBY
  end
end

router = Clearwater::Router.new do
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
      html: {
        name: 'html',
        code: app.html.code,
        show: app.html.show,
      },
      css: {
        name: 'css',
        code: app.css.code,
        show: app.css.show,
      },
      ruby: {
        name: 'ruby',
        code: app.ruby.code,
        show: app.ruby.show,
      },
      show_js: app.show_js,
    }
  end
end

Action = GrandCentral::Action.create

UpdateCode = Action.with_attributes(:language, :code)
ToggleEditor = Action.with_attributes(:language)
ToggleJS = Action.create
SaveApp = Action.with_attributes(:app) do
  def promise
    p AppSerializer.new(app).call
    Promise.resolve
    # Bowser::HTTP.upload("/api/apps/#{app.id}", AppSerializer.new(app).call)
  end
end

class AppState < GrandCentral::Model
  attributes :id, :html, :css, :ruby, :show_js

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

Clearwater::Application.new(
  component: Layout.new,
  element: Bowser.document['#app'],
).call
    RUBY
    show: true,
  ),
  show_js: false,
)

store = GrandCentral::Store.new(initial_state) do |state, action|
  case action
  when UpdateCode
    new_state = state.update(
      action.language.name => action.language.update(
        code: action.code,
      ),
    )
  when ToggleEditor
    state.update(
      action.language.name => action.language.update(
        show: !action.language.show?,
      ),
    )
  when ToggleJS
    state.update show_js: !state.show_js?
  else
    state
  end
end

Action.store = store

app = Clearwater::Application.new(
  component: Layout.new(store),
  router: router,
  element: Bowser.document['#app'],
)

app.call

store.on_dispatch { app.render }
