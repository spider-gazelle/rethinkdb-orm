require "rethinkdb"
require "json"

module RethinkORM
  # Wraps the Changefeed iterator and parses events
  class Changefeed(T)
    enum Event
      Created
      Updated
      Deleted
    end

    record(Change(T),
      value : T,
      event : Event,
    ) do
      include JSON::Serializable

      {% for t in Event.constants.map(&.downcase) %}
      def {{ t }}?
        event.{{ t }}?
      end
      {% end %}
    end

    include Iterator(Change(T))
    include Iterator::IteratorWrapper

    def initialize(@iterator : Iterator(RethinkDB::QueryResult))
    end

    def stop
      begin
        @iterator.stop
      rescue Channel::ClosedError
      end
      super
    end

    def next
      result = wrapped_next
      if result.is_a? Iterator::Stop
        stop
      else
        parse_changes result
      end
    rescue Channel::ClosedError
      raise Error::ChangefeedClosed.new
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
        Change.new(model, Event::Created)
      when {_, nil}
        model = T.from_trusted_json old_val.as(String)
        model.destroyed = true
        Change.new(model, Event::Deleted)
      else
        # Create model from old value
        model = T.from_trusted_json old_val.as(String)
        model.clear_changes_information
        model.assign_attributes_from_trusted_json(new_val.as(String))
        Change.new(model, Event::Updated)
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
          Change(String).new(new_val.as(String), Event::Created)
        when {_, nil}
          Change(String).new(old_val.as(String), Event::Deleted)
        else
          # Create object from old value
          old_json = Hash(String, JSON::Any).from_json(old_val.as(String))
          new_json = Hash(String, JSON::Any).from_json(new_val.as(String))
          json_with_updates = old_json.merge(new_json).to_json
          Change(String).new(json_with_updates, Event::Updated)
        end
      end
    end
  end
end
