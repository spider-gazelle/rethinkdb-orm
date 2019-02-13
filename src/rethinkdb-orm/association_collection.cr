class RethinkORM::AssociationCollection(Owner, Target)
  forward_missing_to all

  def initialize(@owner : Owner, @foreign_key : (Symbol | String), @through : (Symbol | String | Nil) = nil)
  end

  def all
    Target.where({"#{@foreign_key}_id" => @owner.id})
  end

  def where(**attrs)
    attrs = attrs.merge({"#{@foreign_key}_id" => @owner.id})
    Target.where(**attrs)
  end

  def find(value)
    Target.find(value)
  end

  def find!(value)
    Target.find!(value)
  end

  private getter owner
  private getter foreign_key
  private getter through
end
