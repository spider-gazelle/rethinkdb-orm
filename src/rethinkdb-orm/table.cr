module RethinkORM::Table
  TABLE_NAME = nil

  # Macro to manually set the table name of the model
  macro table_name(name)
    {% TABLE_NAME = name.id %}
  end

  macro __process_table__
    {% class_path = @type.name.gsub(/::/, "_").underscore.id %}
    {% table_name = TABLE_NAME || class_path %}
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
