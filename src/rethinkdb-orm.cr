require "./rethinkdb-orm/settings"

module RethinkORM
  extend Settings

  def self.configure
    Settings.configure do |settings|
      yield settings
    end
  end
end

require "./rethinkdb-orm/error"
require "./rethinkdb-orm/base"
