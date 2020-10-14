require "retriable"

require "./connection"
require "./utils/collection"
require "./utils/changefeed"

module RethinkORM::Queries
  alias R = RethinkDB
  alias HasChanges = RethinkDB::DatumTerm | RethinkDB::RowTerm | RethinkDB::RowsTerm

  macro included
    # Cursor of each model in the database
    def self.all(**options)
      cursor = Connection.raw(**options) do |q|
        q.table(table_name)
      end
      Collection(self).new(cursor)
    end

    # Changefeed at document (if id passed) or table level
    #
    # Yields an infinite iterator  of model events
    def self.changes(id : String? = nil, **options)
      cursor = table_query(**options) { |q| id ? q.get(id).changes : q.changes }
      Changefeed(self).new(cursor)
    end

    # Creates a Changefeed on query
    #
    def self.changes(**options, & : RethinkDB::Table -> HasChanges)
      cursor = table_query(**options) do |q|
        change_query = yield q
        change_query.changes
      end
      Changefeed(self).new(cursor)
    end

    # Establishes a changefeed of models in a RethinkDB table
    # Changefeed at document (id passed) or table level
    #
    def self.raw_changes(id : String? = nil, **options)
      cursor = table_query(**options) { |q| id ? q.get(id).changes : q.changes }
      Changefeed::Raw.new(cursor)
    end

    # Creates a Changefeed::Raw on query
    #
    def self.raw_changes(**options, & : RethinkDB::Table -> HasChanges)
      cursor = table_query(**options) do |q|
        query = yield q
        query.changes
      end
      Changefeed::Raw.new(cursor)
    end

    # Lookup document by id
    #
    # Throws if document is not present
    def self.find!(id : String, **options)
      document = find(id, **options)
      raise RethinkORM::Error::DocumentNotFound.new("Key not present: #{id}") unless document
      document
    end

    # Find single document by id
    #
    def self.find(id : String, **options)
      result = table_query(**options) do |q|
        q.get(id)
      end

      self.from_trusted_json(result.to_json) unless result.raw.nil?
    end

    # Look up document by id
    #
    def self.find_all(ids : Array | Tuple, **options)
      get_all(ids, **options)
    end

    # Query by ids, optionally set a secondary index
    #
    def self.get_all(values : Array | Tuple, **options)
      cursor = table_query do |q|
        q.get_all(values, **options)
      end

      Collection(self).new(cursor)
    end

    # Check for document presence in the table
    #
    def self.exists?(id : String, **options)
      result = table_query(**options) do |q|
        q.get(id) != nil
      end

      result.as_bool
    end

    # Returns documents with columns matching the given criteria
    #
    def self.find_by(**attribute)
      where(**attribute)
    end


    # :ditto:
    def self.find_by(**attribute, &predicate : RethinkDB::DatumTerm -> RethinkDB::DatumTerm)
      where(**attribute, &predicate)
    end

    # Returns documents for which predicate block is true
    #
    def self.where(&predicate : RethinkDB::DatumTerm -> RethinkDB::DatumTerm)
      cursor = table_query do |q|
        q.filter(&predicate)
      end
      Collection(self).new(cursor)
    end

    def self.where(**attrs, &predicate : RethinkDB::DatumTerm -> RethinkDB::DatumTerm)
      cursor = table_query do |q|
        q.filter(attrs).filter(&predicate)
      end
      Collection(self).new(cursor)
    end

    def self.where(attrs : Hash, **options)
      cursor = table_query(**options) do |q|
        q.filter(attrs)
      end
      Collection(self).new(cursor)
    end

    # **Unsafe** method until `where` can accept more generic arguments
    # Makes 2 **LARGE** assumptions
    # - User correctly scopes the query under the right table
    # - User forms a query that returns a collection of models
    #
    # Should raise/not compile on malformed query/incorrect return type to create a collection
    def self.collection_query(**options)
      cursor = Connection.raw(**options) do |q|
        yield q.table(table_name)
      end
      Collection(self).new(cursor)
    end

    # **Unsafe** method until `where` can accept more generic arguments
    # Makes 2 **LARGE** assumptions
    # - User correctly scopes the query under the right table
    # - User forms a query that returns a collection of models
    #
    # Should raise/not compile on malformed query/incorrect return type to create a collection
    def self.raw_query(**options)
      cursor = Connection.raw(**options) do |q|
        yield q
      end
      Collection(self).new(cursor)
    end

    # Returns documents containing fields that match the attributes
    #
    def self.where(**attrs)
      where(attrs.to_h)
    end

    # Returns a count of all documents in the table
    #
    def self.count
      result = table_query { |q| q.count }
      result.try(&.as_i) || 0
    end

    # Returns a count of all documents in the table
    #
    def self.count(**attrs)
      result = table_query { |q| q.filter(attrs).count }
      result.try(&.as_i) || 0
    end

    # Returns a count of documents for which predicate block is true
    #
    def self.count(**attrs, &predicate : RethinkDB::DatumTerm -> RethinkDB::DatumTerm)
      result = table_query do |q|
        handle = (attrs.empty? ? q : q.filter(attrs))
        handle.filter(&predicate).count
      end
      result.try(&.as_i) || 0
    end

    # Yield a RethinkDB handle namespaced under the document table
    #
    def self.table_query(**options)
      Connection.raw(**options) do |q|
        yield q.table(table_name)
      end
    end
  end
end
