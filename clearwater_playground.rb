require 'roda'
require 'roda/opal_assets'
require 'clearwater'
require 'grand_central'

require 'api'

class ClearwaterPlayground < Roda
  plugin :public

  assets = Roda::OpalAssets.new

  route do |r|
    r.public
    assets.route r

    r.on('api') { r.run API }

    <<-HTML
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>ClearwaterPlayground</title>
  </head>

  <body>
    <div id="app"></div>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.2.8/ace.js"></script>
    #{assets.js 'app.js'}
  </body>
</html>
    HTML
  end
end
