module RethinkORM::Validators
  macro ensure_unique(field)
    secondary_index({{ field }})

    validate "#{{{ field }}} should be unique", ->(this: self) do
      value = this.{{ field.id }}
      return true if value.nil?

      instance = self.get_all(value, index: {{ field.id.stringify }}).to_a.shift?
      !(instance && instance.id != this.id)
    end
  end
end
