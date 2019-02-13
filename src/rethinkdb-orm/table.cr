module RethinkORM::Table
  SETTINGS = {} of Nil => Nil

  # Macro to manually set the table name of the model
  macro table_name(name)
    {% SETTINGS[:table_name] = name.id %}
  end

  macro __process_table__
    {% class_path = @type.name.gsub(/::/, "_").underscore.id %}
    {% table_name = SETTINGS[:table_name] || class_path %}
    {% RethinkORM::Base::TABLES << table_name.id.stringify %}
    @@table_name = "{{ table_name }}"

    def self.table_name
      @@table_name
    end

    def table_name
      @@table_name
    end
  end
end
