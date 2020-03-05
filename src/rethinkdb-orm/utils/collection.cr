require "crystal-rethinkdb"

module RethinkORM
  class Collection(T)
    include Iterator(T)
    include Iterator::IteratorWrapper

    def initialize(
      @iterator : Iterator(RethinkDB::QueryResult)
    )
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
