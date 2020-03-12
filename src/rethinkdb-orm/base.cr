require "active-model"

require "./associations"
require "./error"
require "./index"
require "./persistence"
require "./queries"
require "./table"
require "./timestamps"
require "./validators/*"
require "./connection"

class RethinkORM::Base < ActiveModel::Model
  include ActiveModel::Validation
  include ActiveModel::Callbacks

  include Associations
  include Index
  include Persistence
  include Queries
  include Table
  include Validators

  # Allows setting of connection for a specific model.
  # Used during the table initialisation, so only the Lock has a connection
  protected class_property __connection : RethinkDB::Connection? = nil

  TABLES  = [] of String
  INDICES = [] of NamedTuple(field: String, table: String)

  macro inherited
      macro finished
        {% unless @type.abstract? %}
        __process_table__
        {% end %}
      end
    end

  # Default primary key
  attribute id : String, es_type: "keyword", mass_assignment: false

  def_equals attributes, changed_attributes
end
