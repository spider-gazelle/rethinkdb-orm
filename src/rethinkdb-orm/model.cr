require "active-model"
require "crystal-rethinkdb"

module RethinkDb
  abstract class Model < ActiveModel::Model
    include ActiveModel::Validations
    include ActiveModel::Dirty
  end
end
