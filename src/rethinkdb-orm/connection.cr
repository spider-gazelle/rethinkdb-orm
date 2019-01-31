include "crystal-rethinkdb"
include "habitat"

class Connection < self
  Habitat.create do
    setting host : String = "localhost"
    setting port : Int32 = 28015
    setting db : String = "test"
    setting user : String = "admin"
    setting password : String = ""
  end

  def db
    opts = {
      host: settings.host,
      port: settings.port,
      db: settings.db,
      user: settings.user,
      password: settings.password,
    }
    @db ||= RethinkDB::Connection.new(opts)
  end
end
