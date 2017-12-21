require 'clearwater/component'

module Routing
  attr_writer :remaining_path, :current_router

  def route(path: remaining_path, base_path: current_router.base_path)
    router = Router.new(path: path, base_path: base_path)
    result = yield router
    router.matches
  end

  # Default to the URL path in the browser window
  def remaining_path
    @remaining_path || Bowser.window.location.path
  end

  def current_router
    @current_router ||= Router.new(path: remaining_path, base_path: '')
  end

  class Router
    attr_reader :base_path, :path, :matches

    def initialize(path:, base_path: '')
      @path = path.to_s
      @base_path = base_path
      @matches = []
    end

    def match candidate_path
      match = check(candidate_path)

      if match
        route = Route.new(base_path, match)

        # If the match length is 2, it means there is the full match and the
        # first capture. We don't want to yield an array if there is only one
        # capture because of how block argument destructuring works.
        # If we get back a Ruby object, find out if we can set its remaining
        # path. If it's a JS object convert it to a Ruby object before checking.
        # If we don't respond to Native, we're probably not in a JS environment
        # so it'll be a Ruby object anyway.
        content = yield route, *match[1..-1]

        matches << content

        if (respond_to?(:Native) ? Native(content) : content).respond_to? :remaining_path=
          content.remaining_path = match.post_match
        end
        if (respond_to?(:Native) ? Native(content) : content).respond_to? :current_router=
          content.current_router = self
          @base_path = route.path
        end
      end

      match
    end

    def miss
      if matches.empty?
        result = yield
        matches << result
        result
      end
    end

    def root
      if path.match %r{^/?$}
        result = yield
        matches << result
        result
      end
    end

    def unique_match candidate_path, &block
      return unless matches.empty?

      match(candidate_path, &block)
    end

    private

    # Check to see if the current path matches a candidate path segment
    # @param candidate_path [String] the path segment to check
    # @return [MatchData] Match data
    def check candidate_path
      # Convert dynamic segments into regexp captures
      matchable_path = candidate_path.gsub(/:\w+/, '([^/]+)')

      # Don't match a partial segment. For example,
      # don't match /widget for /widgets.
      path.match(Regexp.new("^/?#{matchable_path}(?:/|$)"))
    end
  end

  class Redirect
    require 'clearwater/black_box_node'
    include Clearwater::BlackBoxNode

    def self.to path, &block
      new to: path, &block
    end

    def initialize(to:)
      @target = to
    end

    def mount element
      Bowser.window.history.push @target

      # Delay rendering until the next frame so we don't interfere with the
      # current render.
      Bowser.window.animation_frame do
        Clearwater::Component.call
      end
    end
  end

  class ConfirmableLink
    include Clearwater::Component

    def initialize props={}, content=nil, &check
      @props = props.reject { |key, value| key == :message }
      @content = content
      @message = props[:message]
      @check = check || proc { true }
    end

    def render
      a(@props.merge(onclick: method(:onclick)), @content)
    end

    def onclick event
      event.prevent

      @props.fetch(:onclick) { proc {} }.call event

      navigate = !@check.call || `confirm(#@message)`
      navigate_to @props[:href] if navigate
    end

    def navigate_to path
      Bowser.window.history.push path
      call
    end
  end

  class Route
    attr_reader :path

    def initialize base_path, match
      @path = [base_path, match[0]]
        .join('/')
        .sub(%r{/$}, '') # Don't end URL paths in slashes
        .sub('//', '/')  # Duplicate slashes can happen if matches contain them
    end
  end
end

# module Routing
#   attr_accessor :matched_path

#   def route
#     path_matcher = PathMatcher.new(matched_path, Bowser.window.location.path)
#     yield path_matcher
#     path_matcher.matches
#   end

#   class PathMatcher
#     attr_reader :current_match, :current_path, :matches

#     def initialize current_match, current_path
#       @current_match = current_match.to_s
#       @current_path = current_path.to_s
#       @matches = []
#     end

#     def match? segment
#       segment = segment.sub(%r(^/), '')
#       match_check = "#{current_match}/#{segment}"

#       if current_path.start_with? match_check
#         true
#       elsif segment.start_with? ':'
#         current_path.sub(%r(^#{Regexp.escape(current_match)}/?), '')[/^[\w-]+/]
#       end
#     end

#     def match path_segment
#       @matching_path = path_segment
#       match = match? path_segment
#       if match
#         @matches << child_route(yield(match), path_segment)
#         # ChildRoute.new(yield(match), "#{@path_matcher.current_match}/#{path_segment}")
#       end
#       @matching_path = nil
#     end

#     def miss
#       if @matches.none?
#         @matches << ChildRoute.new(yield, current_match)
#       end
#     end

#     def child_route content
#       ChildRoute.new(content, current_match)
#     end

#     ChildRoute = Struct.new(:content, :current_path_match) do
#       include Clearwater::Component

#       def render
#         # Allow for plain JS objects but also check to see if we can use the accessor
#         if `!!(#{content} && #{content}.$$class) && #{content.respond_to? :matched_path=}`
#           content.matched_path = current_path_match
#         end

#         content
#       end
#     end
#   end
# end
