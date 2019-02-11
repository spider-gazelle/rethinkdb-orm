require "active-model"

require "./associations"
require "./connection"
require "./persistence"
require "./queries"
require "./table"

abstract class RethinkORM::Base < ActiveModel::Model
  include ActiveModel::Validation
  include ActiveModel::Callbacks

  include Associations
  include Persistence
  include Table

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
  def_equals attributes
end
