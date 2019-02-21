require "./utils/association_collection"

module RethinkORM::Associations
  # Defines getter and setter for parent relationship
  macro belongs_to(parent_class, dependent = :none, create_index = true)
    {% parent_name = parent_class.id.underscore.downcase.gsub(/::/, "_") %}
    {% foreign_key = parent_name + "_id" %}
    {% association_method = parent_name.id.symbolize %}

    attribute {{ foreign_key.id }} : String
    destroy_callback({{association_method}}, {{dependent}})

    {% if create_index %}
      secondary_index({{ foreign_key.symbolize }})
    {% end %}

    # Retrieves the parent relationship
    def {{ parent_name }}
      if @{{ foreign_key }} && (parent = {{ parent_class }}.find @{{ foreign_key }})
        parent
      else
        {{ parent_class }}.new
      end
    end

    # Sets the parent relationship
    def {{ parent_name }}=(parent)
      @{{ foreign_key }} = parent.id
    end

    # Look up instances of this model dependent on the foreign key
    def self.by_{{ foreign_key }}(id)
      if self.has_index({{ foreign_key.id.stringify }})
        self.get_all(id, index: {{ foreign_key.id.stringify }})
      else
        self.where({{ foreign_key }}: id)
      end
    end
  end

  macro has_one(child_class, dependent = :none, through = nil, create_index = false)
    {% child = child_class.id.underscore.downcase.gsub(/::/, "_") %}
    {% foreign_key = child + "_id" %}
    {% association_method = child.id.symbolize %}

    attribute {{ foreign_key.id }} : String
    destroy_callback({{ association_method }}, {{dependent}})

    {% if create_index %}
      secondary_index({{ foreign_key.id }}, @@table_name)
    {% end %}

    def {{ child.id }} : {{ child_class }}?
      self.{{ foreign_key.id }} ? {{ child_class }}.find(self.{{ foreign_key.id }} )
                                : {{ child_class }}.new
    end

    def {{ child.id }}! : {{ child_class }}
      {{ child_class }}.find(self.{{ foreign_key.id }} )
    end

    def {{ child.id }}=(child)
      self.{{ foreign_key.id }} = child.id
    end
  end

  # Must be used in conjunction with the belongs_to macro
  macro has_many(child_class, collection_name = nil, dependent = :none, through = nil)
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
end
