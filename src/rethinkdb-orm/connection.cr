require "crystal-rethinkdb"
require "habitat"
require "mutex"

include RethinkDB::Shortcuts

class RethinkORM::Connection
  Habitat.create do
    setting host : String = ENV["RETHINKDB_HOST"]? || "localhost"
    setting port : Int32 = (ENV["RETHINKDB_PORT"]? || 28015).to_i
    setting db : String = ENV["RETHINKDB_DATABASE"]? || "test"
    setting user : String = ENV["RETHINKDB_USER"]? || "admin"
    setting password : String = ENV["RETHINKDB_PASSWORD"]? || ""
  end

  @@resource_check = false
  @@resource_lock = Mutex.new

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
  def self.raw
    ensure_resources!

    query = yield r
    query.run(self.db)
  end

  # Passes query builder and datum term of supplied raw json string
  #
  def self.raw_json(json : String)
    self.raw do |q|
      yield q, q.json(json)
    end
  end

  # Lazily check for and create non-existant resources in rethink
  #
  # TODO: support more configuration for db/table sharding and replication
  protected def self.ensure_resources!
    @@resource_lock.synchronize {
      return if @@resource_check

      tables = RethinkORM::Base::TABLES.uniq
      indices = RethinkORM::Base::INDICES.uniq

      db_check = r.branch(
        # If db present
        r.db_list.contains(settings.db),
        # Then noop
        {"dbs_created" => 0},
        # Else create db
        r.db_create(settings.db),
      )

      table_queries = tables.map do |table|
        r.branch(
          # If table present
          r.db(settings.db).table_list.contains(table),
          # Then noop
          {"tables_created" => 0},
          # Else create table
          r.db(settings.db).table_create(table)
        )
      end

      index_creation = indices.map do |index|
        table = index[:table]
        field = index[:field]

        r.branch(
          # If index present
          r.db(settings.db).table(table).index_list.contains(field),
          # Then noop
          {"created" => 0},
          # Else create index
          r.db(settings.db).table(table).index_create(field)
        )
      end

      # Block until the table has been created
      index_existence = indices.map do |index|
        r.db(settings.db).table(index[:table]).index_wait(index[:field])
      end

      # Combine into series of sequentially evaluated expressions
      r.expr([db_check] + table_queries + index_creation + index_existence).run(self.db)

      # TODO: Error check
      @@resource_check = true
    }
  end
end
