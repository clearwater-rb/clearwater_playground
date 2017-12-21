require 'bundler/setup'

$LOAD_PATH << 'lib'

require './clearwater_playground'

use Rack::Session::Cookie, secret: ENV.fetch('SESSION_SECRET') {
  require 'securerandom'
  SecureRandom.hex
}
use Rack::Deflater
use Rack::CommonLogger
run ClearwaterPlayground
