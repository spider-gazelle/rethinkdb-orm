require "./utils/association_collection"

module RethinkORM::Associations
  # Defines getter and setter for parent relationship
  macro belongs_to(assoc, dependent = :none, create_index = true, foreign_key = nil, foreign_type = nil, primary_key = nil, presence = false)
    {% method_name = assoc.var %}
    {% class_name = assoc.type %}
    {% foreign_key ||= method_name.id + "_id" %}
    {% foreign_type ||= String %}
    {% primary_key ||= "id".id %}
    {% assoc_var = "__#{foreign_key.id}".id %}

    attribute {{ foreign_key.id }} : {{ foreign_type }} {% unless presence %} | Nil {% end %}, parent: {{ class_name.id.stringify }}, es_type: "keyword"
    property {{ assoc_var }} : {{ class_name }}?
    destroy_callback({{ foreign_key.id.symbolize }}, {{dependent}})

    {% if create_index %}
      secondary_index({{ foreign_key.id }})
    {% end %}

    # Retrieves the parent relationship
    def {{ method_name.id }} : {{ class_name }}?
      parent = @{{ assoc_var }}
      key = self.{{ foreign_key.id }}

      return parent if parent

      self.{{ assoc_var }} = key ? {{ class_name }}.find(key) : nil
    end

    def {{ method_name.id }}! : {{ class_name }}
      parent = @{{ assoc_var }}
      key = self.{{ foreign_key.id }}

      return parent if parent
      raise RethinkORM::Error.new("No {{ foreign_key.id }} set") unless key

      self.{{ assoc_var }} = {{ class_name }}.find!(key)
    end

    # Sets the parent relationship
    def {{ method_name.id }}=(parent : {{ class_name }})
      self.{{ assoc_var }} = parent
      self.{{ foreign_key.id }} = parent.{{ primary_key.id }}.as({{ foreign_type }})
    end

    def reset_associations
      self.{{ assoc_var }} = nil
    end

    # Look up instances of this model dependent on the foreign key
    def self.by_{{ foreign_key.id }}(id)
      if self.has_index?({{ foreign_key.id.stringify }})
        self.get_all([id], index: {{ foreign_key.id.stringify }})
      else
        self.where({{ foreign_key.id }}: id)
      end
    end
  end

  macro has_one(assoc, dependent = :none, create_index = false, foreign_key = nil, foreign_type = nil, primary_key = nil, presence = false)
    {% method_name = assoc.var %}
    {% class_name = assoc.type %}
    {% foreign_key ||= method_name.id + "_id" %}
    {% foreign_type ||= String %}
    {% primary_key ||= "id".id %}
    {% assoc_var = "__#{foreign_key.id}".id %}

    attribute {{ foreign_key.id }} : {{ foreign_type }} {% unless presence %} | Nil {% end %}
    property {{ assoc_var }} : {{ class_name }}?
    destroy_callback({{ foreign_key.id.symbolize }}, {{dependent}})

    {% if create_index %}
      secondary_index({{ foreign_key.id }})
    {% end %}

    # Get cached child or attempt to load an associated {{method_name.id}}
    def {{ method_name.id }} : {{ class_name }}?
      key = self.{{ foreign_key.id }}
      child = @{{ assoc_var }}
      return child unless child.nil?

      self.{{ assoc_var }} = key {% if foreign_type == String %}&& !key.empty?{% end %} ? {{ class_name }}.find(key) : nil
    end

    def {{ method_name.id }}! : {{ class_name }}
      key = self.{{ foreign_key.id }}
      child = @{{ assoc_var }}
      return child unless child.nil?
      raise RethinkORM::Error.new("No {{ foreign_key.id }} set") unless key

      self.{{ assoc_var }} = {{ class_name }}.find!(key)
    end

    def {{ method_name.id }}=(child)
      self.{{ assoc_var }} = child
      self.{{ foreign_key.id }} = child.{{ primary_key.id }}
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
