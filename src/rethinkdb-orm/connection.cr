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

  @@db_exists = false

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
  #
  # Auto creates the database if its not already present.
  # The block defined query is run and raw results returned.
  def self.raw(&block : -> RethinkDB::Term)
    query = yield db_autocreate
    query.run(self.db)
  end

  # Safely provides db query namespace, creating the db if it does not already exist
  #
  # Returns the db query namespace
  protected def self.db_autocreate
    # Check for presence of db
    @@db_exists = @@db_exists || r.db_list.run(self.db).to_a.map(&.to_s).includes?(settings.db)
    unless @@db_exists
      # Create database
      dbs_created = r.db_create(settings.db).run(self.db)["config_changes"]["dbs_created"].as_i
      @@db_exists = dbs_created == 1
    end
    r.db(settings.db)
  end
end
