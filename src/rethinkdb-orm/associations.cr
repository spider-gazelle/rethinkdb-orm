require "./utils/association_collection"

module RethinkORM::Associations
  # Specifies a one-to-one association with another class. This method should only be used if this class
  # contains the foreign key.
  #
  # Properties:
  # `assoc`
  # :    the method name and type (`name : Type`). An additional field will be created on the model
  #      called {{ method_name }}_id which will correspond to the parent class' ID.
  #
  # `dependent`
  # :    What do do when the parent record is destroyed. Valid options are `:cascade`, `:destroy`, or `:none`
  #
  # `create_index`
  # :    Whether or not to tag this record as a secondary index.
  #
  # `foreign_key`
  # :    Specify the foreign key used for the association. By default this is guessed to be the name of
  #      the association with an `_id` suffix. So a class that defines a `belongs_to Person` association
  #      will use `person_id` as the default foreign_key. Similarly, `belongs_to favorite_person : Person`,
  #      will use a foreign key of `favorite_person_id`.
  #
  # `primary_key`
  # :    Specify the method that returns the primary key of associated object used for the association.
  #      By default this is `id`.
  #
  # `primary_type`
  # :    Specify the class of the `primary_key` if it is not `String` (the default).
  #
  macro belongs_to(assoc, dependent = :none, create_index = true, foreign_key = nil, primary_key = nil, primary_type = nil, dbg = false)
    {% method_name = assoc.var %}
    {% class_name = assoc.type.stringify.split(" | ").first.id %}
    {% presence = !assoc.type.stringify.ends_with?("Nil") %}
    {% foreign_key ||= method_name.id + "_id" %}
    {% primary_type ||= String %}
    {% primary_key ||= "id".id %}
    {% assoc_var = "__#{method_name.id}".id %}

    @{{ assoc_var }} : {{ class_name }}?
    attribute {{ foreign_key.id }} : {{ primary_type }}{% unless presence %} | Nil{% end %}, parent: {{ class_name.id.stringify }}, es_type: "keyword"

    destroy_callback({{ foreign_key.id.symbolize }}, {{dependent}})

    {% if create_index %}
      secondary_index({{ foreign_key.id }})
    {% end %}

    # Retrieves the parent relationship
    def {{ method_name.id }} : {{ class_name }} | Nil
      @{{ assoc_var.id }} ||= {{ class_name }}.find_one({{ primary_key.id }}: self.{{ foreign_key.id }})
      if (parent = @{{ assoc_var.id }}) && (key = parent.{{ primary_key.id }})
        self.{{ foreign_key.id }} ||= key
        parent
      end
    end

    def {{ method_name.id }}! : {{ class_name }}
      parent = @{{ assoc_var }}
      return parent if parent

      key = self.{{ foreign_key.id }}
      raise RethinkORM::Error.new("No {{ foreign_key.id }} set") unless key

      @{{ assoc_var }} = {{ class_name }}.find_one!({{ primary_key.id }}: key)
    end

    # Sets the parent relationship
    def {{ method_name.id }}=(parent : {{ class_name }}{% unless presence %} | Nil{% end %})
      @{{ assoc_var }} = parent
      {% if presence %}\
        self.{{ foreign_key.id }} = parent.{{ primary_key.id }}.as({{ primary_type }})
      {% else %}\
        self.{{ foreign_key.id }} = parent ? parent.{{ primary_key.id }}.as({{ primary_type }}) : nil
      {% end %}\
    end

    def reset_associations
      @{{ assoc_var }} = nil
    end

    # Look up instances of this model dependent on the foreign key
    def self.by_{{ foreign_key.id }}(id)
      if self.has_index?({{ foreign_key.id.symbolize }})
        self.get_all([id], index: {{ foreign_key.id.symbolize }})
      else
        self.where({{ foreign_key.id }}: id)
      end
    end

    {% if dbg %}
      {% debug %}
    {% end %}
  end

  # Specifies a one-to-one association with another class. This method should only be used if the
  # other class contains the foreign key.
  #
  # Properties:
  # `assoc`
  # :    the method name and type (`name : Type`). An additional field will be created on the model
  #      called {{ method_name }}_id which will correspond to the parent class' ID.
  #
  # `dependent`
  # :    What do do when the parent record is destroyed. Valid options are `:cascade`, `:destroy`, or `:none`
  #
  # `create_index`
  # :    Whether or not to tag this record as a secondary index.
  #
  # `foreign_key`
  # :    Specify the foreign key used for the association. By default this is guessed to be the name of
  #      the association with an `_id` suffix. So a class that defines a `has_one Person` association
  #      will use `person_id` as the default foreign_key. Similarly, `has_one favorite_person : Person`,
  #      will use a foreign key of `favorite_person_id`.
  #
  # `primary_key`
  # :    Specify the method that returns the primary key of associated object used for the association.
  #      By default this is `id`.
  #
  # `primary_type`
  # :    Specify the class of the `primary_key` if it is not `String` (the default).
  #
  macro has_one(assoc, dependent = :none, create_index = false, foreign_key = nil, primary_key = nil, primary_type = nil, dbg = false)
    {% method_name = assoc.var %}
    {% id_method_name = method_name.id + "_id" %}
    {% class_name = assoc.type.stringify.split(" | ").first.id %}
    {% presence = !assoc.type.stringify.ends_with?("Nil") %}
    {% foreign_key ||= method_name.id + "_id" %}
    {% primary_type ||= String %}
    {% primary_key ||= "id".id %}
    {% assoc_var = "__#{method_name.id}".id %}
    {% assoc_var_id = "__#{method_name.id}_id".id %}

    @{{ assoc_var }} : {{ class_name }}?

    # Retrieves the child relationship
    def {{ method_name.id }} : {{ class_name }} | Nil
      child = @{{ assoc_var }}
      return child unless child.nil?

      key = self.{{ primary_key.id }}
      @{{ assoc_var }} = key ? {{ class_name }}.find_one({{ foreign_key.id }}: key) : nil
    end

    # Get cached child or attempt to load an associated {{method_name.id}}
    def {{ method_name.id }}! : {{ class_name }}
      child = @{{ assoc_var }}
      return child unless child.nil?

      key = self.{{ primary_key.id }}
      raise RethinkORM::Error.new("No {{ primary_key.id }} set") unless key

      @{{ assoc_var }} = {{ class_name }}.find_one!({{ foreign_key.id }}: key)
    end

    # Sets the child relationship
    def {{ method_name.id }}=(child : {{ class_name }}{% unless presence %} | Nil{% end %})
      @{{ assoc_var }} = child

      key = self.{{ primary_key.id }}
      raise RethinkORM::Error.new("No {{ primary_key.id }} set") unless key

      child.{{ foreign_key.id }} = key
      child.save!

      child
    end

    def reset_associations
      @{{ assoc_var }} = nil
    end

    {% if dbg %}
      {% debug %}
    {% end %}
  end

  # Must be used in conjunction with the belongs_to macro
  macro has_many(assoc, dependent = :none, foreign_key = nil, dbg = nil)
    {% method_name = assoc.var %}
    {% class_name = assoc.type.stringify.split(" | ").first.id %}
    {% association_method = method_name.id.symbolize %}

    destroy_callback({{association_method}}, {{ dependent }})

    def {{ method_name.id }}
      RethinkORM::AssociationCollection(self, {{ class_name.id }}).new(self, {{ foreign_key }})
    end

    {% if dbg %}
      {% debug %}
    {% end %}
  end

  # Generate destroy callbacks for dependent associations
  private macro destroy_callback(method, dependent)
    {% if dependent.id == :destroy || dependent.id == :delete %}

    def destroy_{{ method.id }}
      return unless (association = {{ method.id }})
      if association.is_a?(RethinkORM::AssociationCollection)
        association.each { |model| model.destroy }
      else
        association.destroy
      end
    end

    before_destroy :destroy_{{ method.id }}
    {% end %}
  end

  def reset_associations
    # noop
  end
end
