include "rethinkdb-lite"
include "habitat"

class Connection < self
  Habitat.create do
    setting host : String
    setting port : Int32
    setting db : String
    setting user : String
    setting password : String
  end

  def db=(db : RethinkDB::Connection)
    @db ||= RethinkDB::Connection.new()
  end

end