require "crystal-rethinkdb"

require "./connection"

module RethinkORM::Queries
  extend self

  # Lookup document by id
  #
  # Throws if document is not present
  def find!(id, **options)
    document = find(id, **options)
    raise RethinkORM::Error::DocumentNotFound.new("Key not present: #{id}") unless document
    document
  end

  # Find single document by id
  #
  def find(id, **options)
    documents = find_all(id, **options)
    documents[0]?
  end

  # Look up document by id
  #
  def find_all(*ids, **options)
    objects = Connection.raw do |q|
      q.table(@@table_name).get_all(ids.to_a)
    end
    objects.to_a.map { |o| load o }
  end

  # Check for document presence in the table
  #
  def exists?(id)
    !find(id).nil?
  end

  # Returns documents with columns matching the given criteria
  #
  # Could use `.get_all`, however this requires an index built on the queried field
  # TODO: Implement get_all method once index functionality implemented
  def find_by(**attribute)
    where(**attribute)
  end

  # Returns documents for which predicate block is true
  #
  def where(&predicate : -> Bool)
    objects = Connection.raw do |q|
      q.table(@@table_name).filter(&predicate)
    end
    objects.to_a.map { |o| load o }
  end

  def where(attrs : Hash)
    objects = Connection.raw do |q|
      q.table(@@table_name).filter(attrs)
    end
    objects.to_a.map { |o| load o }
  end

  # Returns documents containing fields that match the attributes
  #
  def where(**attrs)
    where(attrs.to_h)
  end

  # Returns a count of all documents in the table
  #
  def count
    Connection.raw { |q| q.table(@@table_name).count }
  end

  # Unmarshall the object from the DB response object
  #
  private def load(object)
    self.from_trusted_json(object.raw.to_json)
  end
end
