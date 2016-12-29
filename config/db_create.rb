require_relative 'database_connection'

DB.create_table :apps do
  uuid :id, primary_key: true
  String :name
  json :code
  uuid :user_id
end

DB.create_table :users do
  uuid :id, primary_key: true
end
