module RethinkORM::Table
  # Silence compiler, table_name set by macro
  @@table_name : String = ""

  macro included
    macro inherited
      # :nodoc:
      TABLE_NAME = {} of Symbol => String
      __set_default_table__
    end
  end

  private macro __set_default_table__
    table({{ @type.name.gsub(/::/, "_").underscore }})
  end

  # Macro to manually set the table name of the model
  macro table(name)
    {% TABLE_NAME[:name] = name.id.stringify %}
  end

  macro __process_table__
    {% unless RethinkORM::Base::TABLES.includes?(TABLE_NAME[:name]) %}
      {% RethinkORM::Base::TABLES << TABLE_NAME[:name] %}
    {% end %}

    class_getter table_name : String = {{ TABLE_NAME[:name] }}
    getter table_name : String = {{ TABLE_NAME[:name] }}
  end
end
