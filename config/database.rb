require 'neo4j'
require 'neo4j/core/cypher_session/adaptors/http'

# Neo4j requires a password change the first time you login.
# If you change it to something other than "password", make sure
# you specify that here.
url = ENV.fetch('NEO4J_URL') { 'http://neo4j:password@localhost:7474' }

neo4j_adaptor = Neo4j::Core::CypherSession::Adaptors::HTTP.new(url)
Neo4j::ActiveBase.on_establish_session { Neo4j::Core::CypherSession.new(neo4j_adaptor) }
Neo4j::ActiveBase.current_session = Neo4j::Core::CypherSession.new(neo4j_adaptor)
