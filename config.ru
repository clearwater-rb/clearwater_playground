require 'bundler/setup'

$LOAD_PATH << 'lib'

require './clearwater_playground'

use Rack::Session::Cookie, secret: ENV.fetch('SESSION_SECRET')
run ClearwaterPlayground
