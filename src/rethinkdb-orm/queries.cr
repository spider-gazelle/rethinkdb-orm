require "./connection"
require "./utils/collection"
require "./utils/changefeed"

module RethinkORM::Queries
  macro included
    # Cursor of each model in the database
    def self.all
      result = Connection.raw do |q|
        q.table(@@table_name)
      end
      Collection(self).new(result.each)
    end

    # Establishes a changefeed of models in a rethinkdb table
    # If no id provided, changes for each document in the table will be iterated
    def self.changes(id : String? = nil)
      changes_cursor = id ? table_query { |q| q.get(id).changes }
                          : table_query { |q| q.changes }
      # pp! changes_cursor.each
      Changefeed(self).new(changes_cursor)
    end

    # Lookup document by id
    #
    # Throws if document is not present
    def self.find!(id, **options)
      document = find(id, **options)
      raise RethinkORM::Error::DocumentNotFound.new("Key not present: #{id}") unless document
      document
    end

    # Find single document by id
    #
    def self.find(id, **options)
      documents = find_all(id, **options)
      documents.first?
    end

    # Look up document by id
    #
    def self.find_all(*ids, **options)
      get_all(*ids, **options)
    end

    # Query by ids, optionally set a secondary index
    #
    def self.get_all(*ids, **options)
      result = table_query do |q|
        q.get_all(ids.to_a, **options)
      end

      Collection(self).new(result.each)
    end

    # Check for document presence in the table
    #
    def self.exists?(id)
      !find(id).nil?
    end

    # Returns documents with columns matching the given criteria
    #
    # Could use `.get_all`, however this requires an index built on the queried field
    # TODO: Implement get_all method once index functionality implemented
    def self.find_by(**attribute)
      where(**attribute)
    end

    # Returns documents for which predicate block is true
    #
    def self.where(&predicate : -> Bool)
      result = table_query do |q|
        q.filter(&predicate)
      end
      Collection(self).new(result.each)
    end

    def self.where(**attrs, &predicate : -> Bool)
      result = table_query do |q|
        q.filter(attrs).filter(&predicate)
      end
      Collection(self).new(result.each)
    end

    def self.where(attrs : Hash)
      result = table_query do |q|
        q.filter(attrs)
      end
      Collection(self).new(result.each)
    end

    # Returns documents containing fields that match the attributes
    #
    def self.where(**attrs)
      where(attrs.to_h)
    end

    # Returns a count of all documents in the table
    #
    def self.count
      table_query { |q| q.count }
    end

    private def self.table_query
      Connection.raw do |q|
        yield q.table(@@table_name)
      end
    end
  end
end
