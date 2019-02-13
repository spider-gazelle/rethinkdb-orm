require "crystal-rethinkdb"

require "./connection"

# require "./lazy"

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
    documents.first?
  end

  # Look up document by id
  #
  def find_all(*ids, **options)
    result = table_query do |q|
      q.get_all(ids.to_a)
    end

    Collection(self).new(result.each)
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
    result = table_query do |q|
      q.filter(&predicate)
    end
    Collection(self).new(result.each)
  end

  def where(**attrs, &predicate : -> Bool)
    result = table_query do |q|
      q.filter(attrs).filter(&predicate)
    end
    Collection(self).new(result.each)
  end

  def where(attrs : Hash)
    result = table_query do |q|
      q.filter(attrs)
    end
    Collection(self).new(result.each)
  end

  # Returns documents containing fields that match the attributes
  #
  def where(**attrs)
    where(attrs.to_h)
  end

  # Returns a count of all documents in the table
  #
  def count
    table_query { |q| q.count }
  end

  private def table_query(&block)
    Connection.raw do |q|
      yield q.table(@@table_name)
    end
  end
end
