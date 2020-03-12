require "habitat"
require "mutex"
require "rethinkdb"

require "./settings"
require "./base"

module RethinkORM
  class Connection
    extend Settings

    private alias R = RethinkDB

    @@resource_check = false
    @@resource_lock = Mutex.new
    @@db : RethinkDB::Connection? = nil

    def self.db
      @@db.as(RethinkDB::Connection) unless @@db.nil?

      @@resource_lock.synchronize {
        if @@resource_check && @@db
          @@db.as(RethinkDB::Connection)
        else
          @@db = ensure_resources!(new_connection)
        end
      }
    end

    # Passes the query builder to the block.
    #
    # Auto creates the database if its not already present.
    # The block defined query is run and raw results returned.
    def self.raw(connection : RethinkDB::Connection? = self.db)
      connection = self.db unless connection
      query = yield R
      query.run(connection)
    end

    # Passes query builder and datum term of supplied raw json string
    #
    def self.raw_json(json : String, connection : RethinkDB::Connection? = nil)
      raw(connection) do |q|
        yield q, q.json(json)
      end
    end

    protected def self.lock_connection(connection : RethinkDB::Connection? = nil)
    end

    protected def self.lock_db
      yield
    end

    # Lazily check for and create non-existant resources in rethink
    #
    # TODO: support more configuration for db/table sharding and replication
    protected def self.ensure_resources!(connection)
      return connection if @@resource_check

      # Set the connectin on the lock,
      # then grab the table creation lock.
      # for now, let's leave the db initialisation check

      lock_connection(connection)

      tables = RethinkORM::Base::TABLES.uniq
      indices = RethinkORM::Base::INDICES.uniq

      db_check = R.branch(
        # If db present
        R.db_list.contains(settings.db),
        # Then noop
        {"dbs_created" => 0},
        # Else create db
        R.db_create(settings.db),
      )

      lock_db do
        # Group index queries by table
        index_queries = indices.group_by { |index| index[:table] }.transform_values do |queries|
          queries.map do |index|
            table = index[:table]
            field = index[:field]

            # Create index or noop
            creation = R.branch(
              # If index present
              R.db(settings.db).table(table).index_list.contains(field),
              # Then noop
              {"created" => 0},
              # Else create index
              R.db(settings.db).table(table).index_create(field),
            )
            # Wait for index to be ready
            existence = R.db(settings.db).table(table).index_wait(field)

            {creation, existence}
          end
        end

        # Combine table and index queries
        table_queries = tables.map do |table|
          creation_query = R.branch(
            # If table present
            R.db(settings.db).table_list.contains(table),
            # Then noop
            {"tables_created" => 0},
            # Else create table
            R.db(settings.db).table_create(table)
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

        table_queries.each(&.get)

        # TODO: Error check
        @@resource_check = true
      end
      connection
    ensure
      lock_connection(nil)
    end

    protected def self.new_connection
      RethinkDB::Connection.new(
        host: settings.host,
        port: settings.port,
        db: settings.db,
        user: settings.user,
        password: settings.password,
        max_retry_interval: settings.retry_interval,
        max_retry_attempts: settings.retry_attempts,
      )
    end
  end
end
