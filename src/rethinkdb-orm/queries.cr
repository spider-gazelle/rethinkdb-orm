require "crystal-rethinkdb"

require "./connection"

module RethinkORM::Queries
  extend self

  def find(*ids, **options)
    objects = Connection.raw do |q|
      q.table(@@table_name).get_all(ids.to_a)
    end

    objects.to_a.map do |o|
      load(o)
    end
  end

  def exists?(id)
    document = Connection.raw do |r|
      r.table(@@table_name).get(id)
    end
    document.nil?
  end

  def count
    raw { |r| r.table(@@table_name).count }
  end

  private def load(object)
    instance = self.from_trusted_json(object.raw.to_json)
    instance.id = object["id"].to_s
    instance
  end
end
