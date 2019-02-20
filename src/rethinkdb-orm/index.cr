module RethinkORM::Index
  macro secondary_index(field)
    RethinkORM::Base::INDICES << { field: {{ field.id.stringify }}, table: @@table_name }
  end
end
