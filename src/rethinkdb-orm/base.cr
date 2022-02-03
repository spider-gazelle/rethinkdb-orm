require "active-model"

require "./associations"
require "./connection"
require "./index"
require "./persistence"
require "./queries"
require "./table"
require "./timestamps"
require "./error"

require "./validators/*"

abstract class RethinkORM::Base < ActiveModel::Model
  include ActiveModel::Validation
  include ActiveModel::Callbacks

  include Associations
  include Index
  include Persistence
  include Table
  include Queries
  include Validators

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
  attribute id : String?, es_type: "keyword", mass_assignment: false

  def_equals attributes, changed_attributes
end
