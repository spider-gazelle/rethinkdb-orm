class RethinkORM::Changefeed(T)
  include Iterator(T)
  include Iterator::IteratorWrapper

  enum Event
    Created
    Updated
    Deleted
  end

  def initialize(@iterator : Iterator(RethinkDB::QueryResult))
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
      model = T.from_trusted_json new_val.not_nil!
      {value: model, event: Event::Created}
    when {_, nil}
      model = T.from_trusted_json old_val.not_nil!
      {value: model, event: Event::Deleted}
    else
      # Create model from old value
      model = T.from_trusted_json old_val.not_nil!
      model.clear_changes_information
      model.assign_attributes_from_trusted_json(new_val.not_nil!)

      {value: model, event: Event::Updated}
    end
  end
end
