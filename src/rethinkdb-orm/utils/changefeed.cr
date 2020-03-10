require "rethinkdb"

module RethinkORM
  # Wraps the Changefeed iterator and parses events
  class Changefeed(T)
    include Iterator(T)
    include Iterator::IteratorWrapper

    enum Event
      Created
      Updated
      Deleted
    end

    def initialize(@iterator : Iterator(RethinkDB::QueryResult))
    end

    def stop
      @iterator.stop
      super
    end

    def next
      result = wrapped_next
      if result == Iterator::Stop::INSTANCE
        stop
      else
        parse_changes result
      end
    rescue e
      if e.message =~ /Changefeed aborted/
        stop
      else
        raise e
      end
    end

    private def parse_changes(result)
      old_val, new_val = {"old_val", "new_val"}.map do |field|
        result[field].raw.try &.to_json
      end

      case {old_val, new_val}
      when {nil, _}
        model = T.from_trusted_json new_val.as(String)
        {value: model, event: Event::Created}
      when {_, nil}
        model = T.from_trusted_json old_val.as(String)
        model.destroyed = true
        {value: model, event: Event::Deleted}
      else
        # Create model from old value
        model = T.from_trusted_json old_val.as(String)
        model.clear_changes_information
        model.assign_attributes_from_trusted_json(new_val.as(String))

        {value: model, event: Event::Updated}
      end
    end

    # Raw changefeed on a table
    class Raw < Changefeed(String)
      private def parse_changes(result)
        old_val, new_val = {"old_val", "new_val"}.map do |field|
          result[field].raw.try &.to_json
        end

        case {old_val, new_val}
        when {nil, _}
          {value: new_val.as(String), event: Event::Created}
        when {_, nil}
          {value: old_val.as(String), event: Event::Deleted}
        else
          # Create object from old value
          old_json = JSON.parse(old_val.as(String)).as_h
          new_json = JSON.parse(new_val.as(String)).as_h
          json_with_updates = old_json.merge(new_json).to_json

          {value: json_with_updates, event: Event::Updated}
        end
      end
    end
  end
end
