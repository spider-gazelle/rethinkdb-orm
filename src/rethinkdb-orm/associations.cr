module RethinkORM::Associations
  enum Dependency
    Destroy
    Delete
    None
  end

  macro included
    # When the owner destroys, go through and pull the children from each association that has a dependency. DESTROY!!!
    # Look at the logic for through, does this impact dependent associations?
    ASSOCIATIONS = [] of NamedTuple(method: Symbol, dependency: Dependency, through: Nil | Symbol)
  end

  private class Association(Owner, Target)
    forward_missing_to all

    getter dependent : Associations::Dependency

    @foreign_key_name : String | Symbol
    @through : String | Symbol | Nil

    def initialize(@owner : Owner, @foreign_key_name, @dependent = Dependency::None, @through = nil)
    end

    def all
      through.nil? ? Target.where({"#{foreign_key_field}" => @owner.id}) : all_through
    end

    private def all_through
      Connection.raw do |r|
        r.table(Target.table_name).eq_join
      end
    end
  end

  # Defines getter and setter for parent relationship
  macro belongs_to(parent_class)
    {% parent_name = parent_class.id.underscore.gsub(/::/, "_") %}
    attribute {{ parent_name.id }}_id : String

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

  macro has_one(child_class, through = nil)
    {% child = child_class.underscore.downcase %}
    {% parent_name = @type.name.gsub(/::/, "_").underscore.id %}

    # Used for dispatch table
    {% ASSOCIATIONS << {method: child.id.symbolize, dependency: dependency, through: through} %}

    def {{ child.id }}
      return nil unless self.id
      AssociationCollecton(self, {{ child_class }}).new(self)
      {{ child_class }}.where({"{{ parent_name }}_id" => self.id }).first?
    end
  end

  macro has_many(child_class, plural = nil, through = nil, dependency = Dependecy::None)
    {% child_collection = (plural ? plural : child_class + 's').underscore.downcase %}
    {% parent_name = @type.name.gsub(/::/, "_").underscore.id %}

    # Used for dispatch table
    {% ASSOCIATIONS << {method: child_collection.id.symbolize, dependency: dependency, through: through} %}

    def {{ child_collection.id }}
      {{ child_class }}.where({"{{ parent_name }}_id" => self.id })
    end
  end

  macro __process_associations__

    # Calls the method for the corresponding association
    #
    private def delegate_to_association(association)
      case association
      {% for association in ASSOCIATIONS %}
        when {{ association[:method].id }}
          {{ association[:method].id }}
      {% end %}
      end
    end

  end

  def destroy_associations!
    ASSOCIATIONS.each do |association|
      next if collection[:dependency] == Dependency::None
      next unless dependent = delegate_to_association association[:method]

      if dependent.is_a?(Array)
        dependent.all.each { |model| model.destroy }
      else
        dependent.destroy
      end
    end
  end
end
