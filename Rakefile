require 'bundler/setup'

namespace :assets do
  # Declare the variable
  assets = nil

  desc 'Precompile assets for production'
  task precompile: [:boilerplate] do
    assets << 'app.js'
    assets.build
  end

  desc 'Compile playground boilerplate'
  task boilerplate: [:default] do
    Dir['public/assets/playground_boilerplate*.js'].each { |file| FileUtils.rm file }
    assets << 'playground_boilerplate.js'
    assets.build

    Dir['public/assets/playground_boilerplate*.js'].each do |file|
      FileUtils.mv file, 'public/playground_boilerplate.js'
    end
  end

  task :default do
    require 'opal'
    require 'clearwater'
    require 'grand_central'
    require 'roda/opal_assets'

    # Keep a single asset compiler in case we want to use it for multiple tasks.
    assets = Roda::OpalAssets.new(env: :production)
  end
end

require_relative 'config/database'
