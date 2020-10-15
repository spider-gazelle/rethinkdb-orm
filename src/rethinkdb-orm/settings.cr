require "habitat"

module RethinkORM
  module Settings
    Habitat.create do
      setting host : String = ENV["RETHINKDB_HOST"]? || "localhost"
      setting port : Int32 = (ENV["RETHINKDB_PORT"]? || 28015).to_i
      setting db : String = ENV["RETHINKDB_DB"]? || ENV["RETHINKDB_DATABASE"]? || "test"
      setting user : String = ENV["RETHINKDB_USER"]? || "admin"
      setting password : String = ENV["RETHINKDB_PASSWORD"]? || ""
      setting retry_interval : Time::Span = (ENV["RETHINKDB_TIMEOUT"]? || 2).to_i.seconds
      # Driver level reconnection attempts
      setting retry_attempts : Int32 = ENV["RETHINKDB_RETRIES"]?.try(&.to_i) || 10
      # ORM level query retries
      setting query_retries : Int32 = ENV["RETHINKDB_QUERY_RETRIES"]?.try &.to_i || 10
      setting lock_expire : Time::Span = (ENV["RETHINKDB_LOCK_EXPIRE"]? || 30).to_i.seconds
      setting lock_timeout : Time::Span = (ENV["RETHINKDB_LOCK_TIMEOUT"]? || 5).to_i.seconds
    end
  end
end
