require "rethinkdb"

module RethinkORM
  class Collection(T)
    include Iterator(T)
    include Iterator::IteratorWrapper

    @iterator : Iterator(RethinkDB::QueryResult)

    def initialize(iterator : Iterator(RethinkDB::QueryResult) | RethinkDB::QueryResult)
      @iterator = iterator.is_a?(Iterator) ? iterator : iterator.as_a.each
    end

    def next
      result = wrapped_next

      if result == Iterator::Stop::INSTANCE
        stop
      else
        T.from_trusted_json result.to_json
      end
    end

    def stop
      @iterator.stop
      super
    end
  end
end
