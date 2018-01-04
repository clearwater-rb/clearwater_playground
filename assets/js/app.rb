require 'opal'
require 'clearwater'
require 'forwardable'
require 'opal/compiler'
require 'clearwater/black_box_node'
require 'clearwater/memoized_component'
require 'grand_central'

require 'store'
require 'routing'

class Layout
  include Clearwater::Component
  include Routing

  def render
    div([
      h1({ style: Style.heading }, Link.new({ href: '/' }, 'Clearwater Playground')),

      ErrorMessages.new(errors),
      route do |r|
        r.unique_match('playgrounds/:id') { |match, id| Playground.memoize(id)[:playground] }
        r.unique_match('playgrounds') { PlaygroundList.memoize[:playground_list] }
        r.miss { Playground.memoize nil }
      end,
    ])
  end

  def errors
    Store.state.errors
  end

  module Style
    module_function

    def heading
      {
        'font-size': '2.5vh',
        font_family: [
          'Helvetica Neue',
          'Sans-Serif',
        ],
        height: '3vh',
      }
    end
  end
end

class PlaygroundList < Clearwater::MemoizedComponent
  def initialize
    @playgrounds = :loading

    Bowser::HTTP.fetch('/api/playgrounds')
      .then(&:json)
      .then do |json|
        @playgrounds = json[:playgrounds].map { |attrs| Playground.new(attrs) }
        call
      end
  end

  def render
    case @playgrounds
    when :loading
      p 'Loading...'
    when Array
      div([
        ul(@playgrounds.map { |playground|
          li([
            Link.new({ href: "/playgrounds/#{playground.id}" }, [
              playground.name || playground.id,
            ])
          ])
        })
      ])
    end
  end

  class Playground < GrandCentral::Model
    attributes(:id, :name, :html, :css, :ruby)
  end
end

class ErrorMessages
  include Clearwater::Component

  def initialize errors
    @errors = errors
  end

  def render
    return div if @errors.empty?

    ul({ style: Style.container }, @errors.map { |error|
      li([
        button({ onclick: DeleteError[error] }, '⨉'),
        error.message,
      ])
    })
  end

  module Style
    module_function

    def container
      {
        background_color: :pink,
        border: '1px solid red',
        color: :red,
        list_style: :none,
        padding: '1em 1.5em',
      }
    end
  end
end

class Playground < Clearwater::MemoizedComponent
  extend Forwardable

  delegate %w(playground_id name html css ruby js) => :state

  attr_reader :id

  def initialize id
    @id = id
    FetchPlayground.call id if id
  end

  def update new_id
    if new_id != id
      @id = new_id
      FetchPlayground.call new_id
    end
  end

  def render
    div([
      Header.new(name, html, css, ruby),
      CodeEditor.new(playground_id, html, css, ruby, js),
      RunningExample.new(html, css, js),
    ])
  end

  def state
    Store.state
  end
end

class Header
  include Clearwater::Component

  attr_reader :name, :html, :css, :ruby

  def initialize name, html, css, ruby
    @name = name
    @html = html
    @css = css
    @ruby = ruby
  end

  def render
    div([
      input(
        oninput: SetPlaygroundName,
        value: name,
        placeholder: 'Name this app',
        style: {
          font_size: '1.75em',
          font_weight: :bold,
          padding: '0.25em 0.5em',
          margin_bottom: '0.3em',
        }
      ),
      div([
        [html, css, ruby].map { |lang|
          button({ onclick: ToggleEditor[lang] }, "Toggle #{lang.name}")
        },
        button({ onclick: ToggleJS }, 'Toggle compiled JS'),
        button({ onclick: SavePlayground }, 'Save'),
      ]),
    ])
  end
end

class CodeEditor
  include Clearwater::Component

  attr_reader :id, :html, :css, :ruby, :js

  def initialize(id, html, css, ruby, js)
    @id, @html, @css, @ruby, @js = id, html, css, ruby, js
  end

  def render
    div({ style: Style.editor_container }, [
      [html, css, ruby].map { |lang|
        if lang.show?
          div({ style: Style.editor(total_editors) }, [
            AceEditor.new(id, lang)
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
        height: "#{85 / [total_editors, 1].max}vh",
        vertical_align: :top,
      }
    end
  end
end

class AceEditor
  include Clearwater::BlackBoxNode

  attr_reader :playground_id, :editor, :height, :code

  def initialize playground_id, lang
    @playground_id = playground_id
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
        # color: :transparent,
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

    if playground_id != previous.playground_id
      @editor.JS.setValue code.to_s
      @editor.JS.clearSelection
    end

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
        height: '85vh'
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
                console.error(e.stack);
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

app = Clearwater::Application.new(
  component: Layout.new,
  element: Bowser.document['#app'],
)

app.call

Store.on_dispatch { app.render }
