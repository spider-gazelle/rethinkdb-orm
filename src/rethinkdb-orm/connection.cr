require "crystal-rethinkdb"
require "habitat"
include RethinkDB::Shortcuts

class RethinkORM::Connection
  Habitat.create do
    setting host : String = "localhost"
    setting port : Int32 = 28015
    setting db : String = "test"
    setting user : String = "admin"
    setting password : String = ""
  end

  @@resource_check = false

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
    self.create_resources unless @@resource_check

    query = yield r
    query.run(self.db)
  end

  # Lazily check for and create non-existant resources in rethink
  #
  # TODO: support more configuration for db/table sharding and replication
  protected def self.create_resources
    db_check = r.branch(
      # If db present
      r.db_list.contains(settings.db),
      # Then noop
      {"dbs_created" => 0},
      # Else create db
      r.db_create(settings.db),
    )

    table_queries = RethinkORM::Base::TABLES.map do |table|
      r.branch(
        # If table present
        r.db(settings.db).table_list.contains(table),
        # Then noop
        {"tables_created" => 0},
        # Else create table
        r.db(settings.db).table_create(table)
      )
    end

    # Combine into series of sequentially evaluated expressions
    r.expr([db_check] + table_queries).run(self.db)
    # TODO: Error check
    @@resource_check = true
  end
end
