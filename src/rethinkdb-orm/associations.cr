module RethinkORM::Associations
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

  macro has_many(children_class, plural = nil)
    {% children_collection = (plural ? plural : children_class + 's').downcase %}
    {% parent_name = @type.name.gsub(/::/, "_").underscore.id %}

    def {{ children_collection.id }}
      return [] of {{ children_class }} unless self.id
      {{ children_class }}.where({"{{ parent_name }}_id" => self.id })
    end
  end
end
