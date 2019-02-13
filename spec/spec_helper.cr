require "spec"

require "../src/rethinkdb-orm"
require "../src/rethinkdb-orm/*"
require "../src/rethinkdb-orm/**"
require "./spec_models"

db_name = "test_#{Time.now.to_unix}_#{rand(10000)}"

RethinkORM::Connection.configure do |settings|
  settings.db = db_name
end

# Tear down the test database
at_exit do
  RethinkORM::Connection.raw do |q|
    q.db_drop(db_name)
  end
end
