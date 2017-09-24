require 'bundler/setup'
require 'opal'
require 'clearwater'
require 'grand_central'
require 'roda/opal_assets'

namespace :assets do
  # Keep a single asset compiler in case we want to use it for multiple tasks.
  assets = Roda::OpalAssets.new(env: :production)

  desc 'Precompile assets for production'
  task precompile: :boilerplate do
    assets << 'app.js'
    assets.build
  end

  desc 'Compile playground boilerplate'
  task :boilerplate do
    Dir['public/assets/playground_boilerplate*.js'].each { |file| FileUtils.rm file }
    assets << 'playground_boilerplate.js'
    assets.build

    Dir['public/assets/playground_boilerplate*.js'].each do |file|
      FileUtils.mv file, 'public/playground_boilerplate.js'
    end
  end
end
