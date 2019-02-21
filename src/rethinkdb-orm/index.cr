module RethinkORM::Index
  macro secondary_index(field)
    RethinkORM::Base::INDICES << { field: {{ field.id.stringify }}, table: @@table_name }
  end

  macro included
    def self.has_index(field)
      RethinkORM::Base::INDICES.any? do |index|
        self.table_name == index[:table] && field == index[:field]
      end
    end
  end
end
