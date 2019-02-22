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
  end

  private def parse_changes(result)
    old_val, new_val = {"old_val", "new_val"}.map do |field|
      val = result[field].raw
      T.from_trusted_json val.to_json unless val.nil?
    end

    case {old_val, new_val} # ameba:disable Lint/LiteralInCondition
    when {nil, _}
      {value: new_val, event: Event::Created}
    when {_, nil}
      {value: nil, event: Event::Deleted}
    else
      updated = apply_changes(old_val, new_val)
      {value: updated, event: Event::Updated}
    end
  end

  private def apply_changes(old_val, new_val)
    new_attributes = new_val.attributes.reduce({} of String => String) do |attrs, kv|
      key, value = kv
      unless value.nil?
        attrs[key.to_s] = value.to_s
      end
      attrs
    end

    old_val.assign_attributes(new_attributes)
    old_val
  end
end
