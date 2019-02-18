require "./association_collection"

module RethinkORM::Associations
  enum Dependency
    Destroy
    Delete
    None
  end

  macro included
    ASSOCIATIONS = {} of String =>  Array(NamedTuple(method: Symbol, dependency: Dependency, through: Nil | Symbol))
  end

  macro inherited
    macro finished
      __process_associations__
    end
  end

  # Defines getter and setter for parent relationship
  macro belongs_to(parent_class, dependent = Dependency::None)
    {% parent_name = parent_class.id.underscore.downcase.gsub(/::/, "_") %}
    {% foreign_key = parent_name + "_id" %}
    attribute {{ foreign_key.id }} : String

    # Used for dispatch table
    {% if !ASSOCIATIONS[@type.name.id] %}
      {% ASSOCIATIONS[@type.name.id] = [] of Nil %}
    {% end %}
    {% ASSOCIATIONS[@type.name.id] << {method: parent_name.symbolize, dependency: dependent} %}

    # Retrieves the parent relationship
    def {{ parent_name }}
      if parent = {{ parent_class }}.find {{ parent_name.id }}_id
        parent
      else
        {{ parent_class }}.new
      end
    end

    # Sets the parent relationship
    def {{ parent_name }}=(parent)
      @{{ parent_name.id }}_id = parent.id
    end
  end

  macro has_one(child_class, dependent = Dependency::None, through = nil)
    {% child = child_class.id.underscore.downcase.gsub(/::/, "_") %}
    {% foreign_key = child + "_id" %}

    attribute {{ foreign_key.id }} : String

    # Used for dispatch table
    {% if !ASSOCIATIONS[@type.name.id] %}
      {% ASSOCIATIONS[@type.name.id] = [] of Nil %}
    {% end %}
    {% ASSOCIATIONS[@type.name.id] << {method: child.id.symbolize, dependency: dependent, through: through} %}

    def {{ child.id }} : {{ child_class }}?
      {{ child_class }}.find(self.{{ foreign_key.id }} )
    end

    def {{ child.id }}! : {{ child_class }}
      {{ child_class }}.find(self.{{ foreign_key.id }} )
    end

    def {{ child.id }}=(child)
      self.{{ foreign_key.id }} = child.id
    end
  end

  macro has_many(child_class, plural = nil, through = nil, dependent = Dependency::None)
    {% child_collection = (plural ? plural : child_class + 's').underscore.downcase %}

    # Used for dispatch table
    {% if !ASSOCIATIONS[@type.name.id] %}
      {% ASSOCIATIONS[@type.name.id] = [] of Nil %}
    {% end %}
    {% ASSOCIATIONS[@type.name.id] << {method: child_collection.id.symbolize, dependency: dependent, through: through} %}

    def {{ child_collection.id }}
      RethinkORM::AssociationCollection(self, {{ child_class }}).new(self)
    end
  end

  macro __process_associations__

    # Calls the method for the corresponding association
    #
    private def delegate_to_association(association)
      case association
      {% for association in ASSOCIATIONS[@type.name.id] %}
      when {{ association[:method] }}
        {{ association[:method].id }}
      {% end %}
      end
    end

    before_destroy do
    # private def destroy_associations!
      p "hellooooo"
      ASSOCIATIONS[@type.name.id].each do |association|
        pp! association
        next if association[:dependency] == Dependency::None
        dependent = delegate_to_association association[:method]
        next unless dependent
        if dependent.is_a?(RethinkORM::AssociationCollection)
          dependent.each { |model| model.destroy }
        else
          dependent.destroy
        end
      end
    end
  end
end
