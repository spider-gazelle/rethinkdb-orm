require "./utils/association_collection"

module RethinkORM::Associations
  # Defines getter and setter for parent relationship
  macro belongs_to(parent_class, dependent = :none, create_index = true)
    {% parent_name = parent_class.id.underscore.downcase.gsub(/::/, "_") %}
    {% foreign_key = parent_name + "_id" %}
    {% assoc_var = ("__" + parent_name.id.stringify).id %}
    {% association_method = parent_name.id.symbolize %}

    attribute {{ foreign_key.id }} : String, parent: {{ parent_class.id.stringify }}
    property {{ assoc_var }} : {{ parent_class }}?
    destroy_callback({{association_method}}, {{dependent}})

    {% if create_index %}
      secondary_index({{ foreign_key.id }})
    {% end %}

    # Retrieves the parent relationship
    def {{ parent_name }} : {{ parent_class }}?
      parent = self.{{ assoc_var.id }}
      return parent unless parent.nil?

      self.{{ assoc_var.id }} = self.{{ foreign_key.id }} ? {{ parent_class }}.find(self.{{ foreign_key.id }})
                                                          : {{ parent_class }}.new
    end

    def {{ parent_name }}! : {{ parent_class }}
      parent = self.{{ assoc_var.id }}
      return parent unless parent.nil?
      return {{ parent_class }}.new if self.{{ foreign_key.id }}.nil?

      self.{{ assoc_var.id }} = {{ parent_class }}.find!(self.{{ foreign_key.id }})
    end

    # Sets the parent relationship
    def {{ parent_name }}=(parent)
      self.{{ assoc_var }} = parent
      self.{{ foreign_key }} = parent.id
    end

    def reset_associations
      self.{{ assoc_var }} = nil
    end

    # Look up instances of this model dependent on the foreign key
    def self.by_{{ foreign_key }}(id)
      if self.has_index?({{ foreign_key.id.stringify }})
        self.get_all(id, index: {{ foreign_key.id.stringify }})
      else
        self.where({{ foreign_key }}: id)
      end
    end
  end

  macro has_one(child_class, dependent = :none, create_index = false)
    {% child = child_class.id.underscore.downcase.gsub(/::/, "_") %}
    {% assoc_var = ("__" + child.id.stringify).id %}
    {% foreign_key = child + "_id" %}
    {% association_method = child.id.symbolize %}

    attribute {{ foreign_key.id }} : String
    property {{ assoc_var }} : {{ child_class }}?
    destroy_callback({{ association_method }}, {{dependent}})

    {% if create_index %}
      secondary_index({{ foreign_key.id }})
    {% end %}

    # Get cached child, load or create a new child
    def {{ child.id }} : {{ child_class }}?
      child = self.{{ assoc_var }}
      return child unless child.nil?

      self.{{ assoc_var }} = self.{{ foreign_key.id }} ? {{ child_class }}.find(self.{{ foreign_key.id }})
                                                       : nil
    end

    def {{ child.id }}! : {{ child_class }}
      child = self.{{ assoc_var }}
      return child unless child.nil?
      return {{ child_class }}.new if self.{{ foreign_key.id }}.nil?

      self.{{ assoc_var }} = {{ child_class }}.find!(self.{{ foreign_key.id }} )
    end

    def {{ child.id }}=(child)
      self.{{ assoc_var }} = child
      self.{{ foreign_key.id }} = child.id
    end

    def reset_associations
      self.{{ assoc_var }} = nil
    end
  end

  # Must be used in conjunction with the belongs_to macro
  macro has_many(child_class, collection_name = nil, dependent = :none)
    {% child_collection = (collection_name ? collection_name : child_class + 's').underscore.downcase %}
    {% association_method = child_collection.id.symbolize %}

    destroy_callback({{association_method}}, {{ dependent }})

    def {{ child_collection.id }}
      RethinkORM::AssociationCollection(self, {{ child_class }}).new(self)
    end
  end

  # Generate destroy callbacks for dependent associations
  private macro destroy_callback(method, dependent)
    {% if dependent.id == :destroy || dependent.id == :delete %}

    def destroy_{{ method.id }}
      return unless association = {{ method.id }}
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
