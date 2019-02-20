require "active-model"

require "./associations"
require "./connection"
require "./index"
require "./persistence"
require "./queries"
require "./table"

abstract class RethinkORM::Base < ActiveModel::Model
  include ActiveModel::Validation
  include ActiveModel::Callbacks

  include Associations
  include Index
  include Persistence
  include Table

  extend Queries

  TABLES  = [] of String
  INDICES = [] of NamedTuple(field: String, table: String)

  macro inherited
    __process_table__
  end

  # Default primary key
  attribute id : String

  # TODO: Is this the best way to do this?
  def_equals attributes, changed_attributes
end
