require "crystal-rethinkdb"
require "habitat"

class RethinkORM::Connection
  Habitat.create do
    setting host : String = "localhost"
    setting port : Int32 = 28015
    setting db : String = "test"
    setting user : String = "admin"
    setting password : String = ""
  end

  def self.db
    opts = {
      host:     settings.host,
      port:     settings.port,
      db:       settings.db,
      user:     settings.user,
      password: settings.password,
    }
    @@db ||= RethinkDB::Connection.new(opts)
  end

  # Passes the query builder to the block.
  # The block defined query is run and raw results returned
  def self.raw(&block : -> RethinkDB::Term)
    query = yield r
    query.run(self.db)
  end
end
