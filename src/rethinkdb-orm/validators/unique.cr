module RethinkORM::Validators
  # In case of transformations on field, allow user defined transform
  macro ensure_unique(field, scope = nil, create_index = true, callback = nil, &transform)

      {% if create_index %}
        secondary_index({{ field }})
      {% end %}


      validate "#{ {{ field }} } should be unique", ->(this: self) do
        value = this.{{ field.id }}
        return true if value.nil?

        {% scope_array = [] of Nil %}
        {% if scope %}
          {% scope_array = scope %}
        {% end %}

        {% if scope_array.empty? %}

          argument = value
          {% proc_type = FIELDS[field.id][:klass] %}

        {% else %}
          # Check if any arguments to the transform are nil
          {% for s in scope_array %}
            return true if this.{{s.id}}.nil?
          {% end %}

          argument = {
          {% for s in scope_array %}
            this.{{s.id}}.not_nil!,
          {% end %}
          }

          # Forgive me mother, for I have sinned
          {% proc_type = "Tuple(#{scope_array.map { |s| FIELDS[s.id][:klass] }.join(", ").id})".id %}
        {% end %}

        {% if transform %}
          # Construct a proc from a given block
          value = ->( {{ transform.args[0] }}  : {{ proc_type }} ) { {{ transform.body }} }.call argument
        {% elsif callback %}
          value = argument.is_a?(Tuple) ? this.{{ callback.id }} *argument : this.{{ callback.id }} argument
        {% end %}

        {% if create_index %}
          # Utilise generated secondary index
          instance = self.get_all([value], index: {{ field.id.stringify }}).to_a.shift?
        {% else %}
          # Otherwise, fallback to where query
          instance = self.where({{field.id}}: value).to_a.shift?
        {% end %}

        success = !(instance && instance.id != this.id)
        this.{{ field.id }} = value if success && !this.persisted?
        success
      end
    end
end
