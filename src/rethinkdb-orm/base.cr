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

  macro inherited
    __process_table__
  end

  macro finished
    # __process_persistence__
    # __process_queries__
  end

  # Default primary key
  attribute id : String

  # TODO: Is this the best way to do this?
  def ==(object)
    object.attributes == attributes && object.id == @id
  end
end
