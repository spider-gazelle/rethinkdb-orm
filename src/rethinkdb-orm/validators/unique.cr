module RethinkORM::Validators
  macro ensure_unique(field)
    validate "#{{{ field }}} should be unique", ->(this: self) do
      return true if this.{{ field.id }}.nil?
      instance = self.where({{field.id}}: this.{{field.id}}).to_a.shift?
      !(instance && instance.id != this.id)
    end
  end
end
