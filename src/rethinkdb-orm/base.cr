require "active-model"
require "crystal-rethinkdb"
include RethinkDB::Shortcuts

require "./persistence"
require "./queries"
require "./table"
require "./connection"

abstract class RethinkORM::Base < ActiveModel::Model
  include ActiveModel::Validation
  include ActiveModel::Callbacks

  include Table
  include Persistence

  extend Queries

  @__key__ : String | Nil
  @id : String | Nil

  macro inherited
    __process_table__
  end

  macro finished
    # __process_persistence__
    # __process_queries__
  end

  # Retrieve id
  def id
    @__key__ || @id
  end

  # Lazily instantiate db connection
  def self.db
    @@db ||= Connection.db
  end

  # Allow manual override of db connection
  def self.db=(db : RethinkDB::Connection)
    @@db = db
  end

  def self.raw(&block)
    Connection.raw(&block)
  end
end
