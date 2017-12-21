require './config/database'

class Playground
  include Neo4j::ActiveNode

  property :name, type: String
  property :html, type: String
  property :css, type: String
  property :ruby, type: String
end
