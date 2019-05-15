require "spec"
require "faker"

require "../src/rethinkdb-orm"
require "../src/rethinkdb-orm/*"
require "../src/rethinkdb-orm/**"
require "./spec_models"

module SpecHelper
  DB_NAME = "test_#{Time.now.to_unix}_#{rand(10000)}"
end

RethinkORM::Connection.configure do |settings|
  settings.db = SpecHelper::DB_NAME
end

# Tear down the test database
at_exit do
  RethinkORM::Connection.raw do |q|
    q.db_drop(SpecHelper::DB_NAME)
  end
end
