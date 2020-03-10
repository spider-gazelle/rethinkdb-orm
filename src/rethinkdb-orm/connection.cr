require "habitat"
require "mutex"
require "rethinkdb"

include RethinkDB::Shortcuts

class RethinkORM::Connection
  Habitat.create do
    setting host : String = ENV["RETHINKDB_HOST"]? || "localhost"
    setting port : Int32 = (ENV["RETHINKDB_PORT"]? || 28015).to_i
    setting db : String = ENV["RETHINKDB_DB"]? || ENV["RETHINKDB_DATABASE"]? || "test"
    setting user : String = ENV["RETHINKDB_USER"]? || "admin"
    setting password : String = ENV["RETHINKDB_PASSWORD"]? || ""
    setting retry_interval : Time::Span = (ENV["RETHINKDB_TIMEOUT"]? || 2).to_i.seconds
    setting retry_attempts : Int32? = ENV["RETHINKDB_RETRIES"]?.try &.to_i
  end

  @@resource_check = false
  @@resource_lock = Mutex.new
  @@db : RethinkDB::Connection? = nil

  def self.db
    @@db.as(RethinkDB::Connection) unless @@db.nil?

    @@resource_lock.synchronize {
      if @@resource_check && @@db
        @@db.as(RethinkDB::Connection)
      else
        connection = RethinkDB::Connection.new(
          host: settings.host,
          port: settings.port,
          db: settings.db,
          user: settings.user,
          password: settings.password,
          max_retry_interval: settings.retry_interval,
          max_retry_attempts: settings.retry_attempts,
        )

        ensure_resources!(connection)
        @@db = connection

        connection
      end
    }
  end

  # Passes the query builder to the block.
  #
  # Auto creates the database if its not already present.
  # The block defined query is run and raw results returned.
  def self.raw
    query = yield r
    query.run(db)
  end

  # Passes query builder and datum term of supplied raw json string
  #
  def self.raw_json(json : String)
    raw do |q|
      yield q, q.json(json)
    end
  end

  # Lazily check for and create non-existant resources in rethink
  #
  # TODO: support more configuration for db/table sharding and replication
  protected def self.ensure_resources!(connection)
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

    # Group index queries by table
    index_queries = indices.group_by { |index| index[:table] }.transform_values do |queries|
      queries.map do |index|
        table = index[:table]
        field = index[:field]

        # Create index or noop
        creation = r.branch(
          # If index present
          r.db(settings.db).table(table).index_list.contains(field),
          # Then noop
          {"created" => 0},
          # Else create index
          r.db(settings.db).table(table).index_create(field)
        )
        # Wait for index to be ready
        existence = r.db(settings.db).table(index[:table]).index_wait(index[:field])

        {creation, existence}
      end
    end

    # Combine table and index queries
    table_queries = tables.map do |table|
      creation_query = r.branch(
        # If table present
        r.db(settings.db).table_list.contains(table),
        # Then noop
        {"tables_created" => 0},
        # Else create table
        r.db(settings.db).table_create(table)
      )
      {creation_query, index_queries[table]?}
    end

    # create DB
    db_check.run(connection)

    # create tables and indexes
    table_queries = table_queries.map do |table_creation, index_creation|
      future {
        table_creation.run(connection)
        index_creation.try &.map do |create, wait|
          create.run(connection)
          future { wait.run(connection) }
        end.each(&.get)
      }
    end

    table_queries.each &.get

    # TODO: Error check
    @@resource_check = true
  end
end
