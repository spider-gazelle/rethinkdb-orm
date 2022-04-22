require "./utils/association_collection"

module RethinkORM::Associations
  # Defines getter and setter for parent relationship
  macro belongs_to(parent_class, dependent = :none, create_index = true, association_name = nil, foreign_key = nil, presence = false)
    {% parent_name = association_name || parent_class.id.stringify.underscore.downcase.gsub(/::/, "_") %}
    {% foreign_key = (foreign_key || "#{parent_name.id}_id").id %}
    {% association_method = parent_name.id.symbolize %}
    {% assoc_var = "__#{parent_name.id}".id %}

    # Prevent association from being serialised
    @[JSON::Field(ignore: true)]
    @[YAML::Field(ignore: true)]
    @{{ assoc_var }} : {{ parent_class }}?

    property {{ assoc_var }} : {{ parent_class }}?
    attribute {{ foreign_key.id }} : String {% unless presence %} | Nil {% end %}, parent: {{ parent_class.id.stringify }}, es_type: "keyword"

    destroy_callback({{ association_method }}, {{dependent}})

    {% if create_index %}
      secondary_index({{ foreign_key.id }})
    {% end %}

    # Retrieves the parent relationship
    def {{ parent_name.id }} : {{ parent_class }}?
      parent = @{{ assoc_var }}
      key = self.{{ foreign_key }}

      return parent if parent

      self.{{ assoc_var }} = key ? {{ parent_class }}.find(key) : nil
    end

    def {{ parent_name.id }}! : {{ parent_class }}
      parent = @{{ assoc_var }}
      key = self.{{ foreign_key }}

      return parent if parent
      raise RethinkORM::Error.new("No {{ foreign_key }} set") unless key

      self.{{ assoc_var }} = {{ parent_class }}.find!(key)
    end

    # Sets the parent relationship
    def {{ parent_name.id }}=(parent : {{ parent_class }})
      self.{{ assoc_var }} = parent
      self.{{ foreign_key.id }} = parent.id.as(String)
    end

    def reset_associations
      self.{{ assoc_var }} = nil
    end

    # Look up instances of this model dependent on the foreign key
    def self.by_{{ foreign_key.id }}(id)
      if self.has_index?({{ foreign_key.id.stringify }})
        self.find_all([id], index: {{ foreign_key.id.stringify }})
      else
        self.where({{ foreign_key }}: id)
      end
    end
  end

  macro has_one(child_class, dependent = :none, create_index = false, association_name = nil, presence = false)
    {% child = association_name || child_class.id.underscore.downcase.gsub(/::/, "_") %}
    {% assoc_var = "__#{child.id}".id %}
    {% foreign_key = child + "_id" %}
    {% association_method = child.id.symbolize %}

    # Prevent association from being serialised
    @[JSON::Field(ignore: true)]
    @[YAML::Field(ignore: true)]
    @{{ assoc_var }} : {{ child_class }}?

    property {{ assoc_var }} : {{ child_class }}?
    attribute {{ foreign_key.id }} : String {% unless presence %} | Nil {% end %}
    destroy_callback({{ association_method }}, {{dependent}})

    {% if create_index %}
      secondary_index({{ foreign_key.id }})
    {% end %}

    # Get cached child or attempt to load an associated {{child.id}}
    def {{ child.id }} : {{ child_class }}?
      key = self.{{ foreign_key.id }}
      child = @{{ assoc_var }}
      return child unless child.nil?

      self.{{ assoc_var }} = key && !key.empty? ? {{ child_class }}.find(key)
                                                : nil
    end

    def {{ child.id }}! : {{ child_class }}
      key = self.{{ foreign_key.id }}
      child = @{{ assoc_var }}
      return child unless child.nil?
      raise RethinkORM::Error.new("No {{ foreign_key.id }} set") unless key

      self.{{ assoc_var }} = {{ child_class }}.find!(key)
    end

    def {{ child.id }}=(child)
      self.{{ assoc_var }} = child
      self.{{ foreign_key.id }} = child.id.as(String)
    end

    def reset_associations
      self.{{ assoc_var }} = nil
    end
  end

  # Must be used in conjunction with the belongs_to macro
  macro has_many(child_class, collection_name = nil, dependent = :none, foreign_key = nil)
    {% child_collection = (collection_name ? collection_name : child_class + 's').underscore.downcase %}
    {% association_method = child_collection.id.symbolize %}

    destroy_callback({{association_method}}, {{ dependent }})

    def {{ child_collection.id }}
      RethinkORM::AssociationCollection(self, {{ child_class }}).new(self, {{ foreign_key }})
    end
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
