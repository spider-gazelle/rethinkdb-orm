module RethinkORM::Validators
  # In case of transformations on field, allow user defined transform
  macro ensure_unique(field, create_index = true, callback = nil, &transform)

      {% if create_index %}
        secondary_index({{ field }})
      {% end %}


      validate "#{ {{ field }} } should be unique", ->(this: self) do
        value = this.{{ field.id }}
        return true if value.nil?

        {% field_type = FIELDS[field.id][:klass] %}
        {% if transform %}
            # Construct a proc from a given block
            value = ->( {{ transform.args[0] }}  : {{ field_type }} ) { {{ transform.body }} } .call value
        {% elsif callback %}
            value = this.{{ callback.id }} value
        {% end %}

        {% if create_index %}
          # Utilise generated secondary index
          instance = self.get_all([value], index: {{ field.id.stringify }}).to_a.shift?
        {% else %}
          # Otherwise, fallback to where query
          instance = self.where({{field.id}}: value).to_a.shift?
        {% end %}

        !(instance && instance.id != this.id)
      end
    end
end
