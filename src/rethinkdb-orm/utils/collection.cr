require "rethinkdb"

module RethinkORM
  class Collection(T)
    include Enumerable(T)

    delegate each, to: iterator

    private getter iterator : CollectionIterator(T)

    def initialize(iterator : Iterator(RethinkDB::QueryResult) | RethinkDB::QueryResult)
      @iterator = CollectionIterator(T).new(iterator)
    end

    # :nodoc:
    class CollectionIterator(T)
      include Iterator(T)
      include Iterator::IteratorWrapper

      @iterator : Iterator(RethinkDB::QueryResult)

      def initialize(iterator : Iterator(RethinkDB::QueryResult) | RethinkDB::QueryResult)
        @iterator = iterator.is_a?(Iterator) ? iterator : iterator.as_a.each
      end

      @atom_response : Iterator(T)? = nil

      def next : T | Iterator::Stop
        result = if (iter = @atom_response)
                   iter.next
                 else
                   wrapped_next
                 end

        return stop if result.is_a?(Iterator::Stop)
        return result if result.is_a?(T)

        begin
          T.from_trusted_json result.to_json
        rescue e : JSON::MappingError
          raise e unless e.message.try &.includes?("Expected BeginObject but was BeginArray")
          atom_iterator = result.as(RethinkDB::QueryResult)
            .as_a
            .map { |object| T.from_trusted_json(object.to_json) }
            .each

          @atom_response = atom_iterator

          atom_iterator.next
        end
      end

      def stop
        @iterator.stop
        super
      end
    end
  end
end
