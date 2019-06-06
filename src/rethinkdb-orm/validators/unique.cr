module RethinkORM::Validators
  # In case of transformations on field, allow user defined transform
  macro ensure_unique(field, scope = [] of Nil, create_index = true, callback = nil, &transform)
      {% if create_index %}
        secondary_index({{ field }})
      {% end %}

      validate "#{ {{ field }} } should be unique", ->(this: self) do
        {% if scope.empty? %}
          {% scope = [field] %}
          {% proc_return_type = FIELDS[field.id][:klass] %}
        {% else %}
          {% proc_return_type = "Tuple(#{scope.map { |s| FIELDS[s.id][:klass] }.join(", ").id})".id %}
        {% end %}

        # Construct proc type fron scope array (forgive me mother, for I have sinned)
        {% proc_arg_type = "#{scope.map { |s| FIELDS[s.id][:klass] }.join(", ").id}".id %}
        {% signature = "#{scope.map { |s| "#{s.id}: #{FIELDS[s.id][:klass]}" }.join(", ").id}".id %}

        # Return if any values are nil
        {% for s in scope %}
          return true if this.{{s.id}}.nil?
        {% end %}

        # Handle Transformation block/callback
        {% if transform %}
          # Construct a proc from a given block, call with argument
          transform_proc : Proc({{ proc_arg_type }}, {{ proc_return_type }}) = ->({{ signature.id }}) { {{ transform.body }} }

          result : {{ proc_return_type }} = transform_proc.call(
            {% for s in scope %}this.{{s.id}}.not_nil!,{% end %}
          )
        {% elsif callback %}
          result : {{ proc_return_type }} = this.{{ callback.id }}(
            {% for s in scope %}this.{{s.id}}.not_nil!,{% end %}
          )
        {% else %}
          # No transform
          result = {
            {% for s in scope %}this.{{s.id}}.not_nil!,{% end %}
          }
        {% end %}

        # Fetch Document
        {% if scope.size == 1 %}
          # Utilise generated secondary index
          {% if create_index %}
            doc = self.get_all([result], index: {{ field.id.stringify }}).first?
          {% else %}
            doc = self.where({{field.id}}: result).first?
          {% end %}
        {% else %}
          # Where query with all scoped fields
          doc = self.where(
            {% for s, index in scope %}{{s.id}}: result[{{ index.id }}], {% end %}
          ).first?
        {% end %}

        # Fields are not present in another document under present table
        success = !(doc && doc.id != this.id)
        {% if transform || callback %}
          # Set fields in unique scope with result of transform block if document is unique
          if success && !this.persisted?
            {% if scope.size == 1 %}
              this.{{ field.id }} = result
            {% else %}
              {% for s, index in scope %}
                this.{{ s.id }} = result[{{ index.id }}]
              {% end %}
            {% end %}
          end
        {% end %}

        success
      end
    end
end
