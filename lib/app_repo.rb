require './config/database'

class AppRepo
  def self.[] id
    new[id]
  end

  def initialize
    @repo = DB[:apps]
  end

  def [](id, user_id: nil)
    query = @repo.where(id: id)
    query = query.where(user_id: user_id) if user_id
    query.first
  end
end
