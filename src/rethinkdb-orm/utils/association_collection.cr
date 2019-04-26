require "../index"

class RethinkORM::AssociationCollection(Owner, Target)
  forward_missing_to all

  def initialize(@owner, foreign_key = nil)
    @foreign_key = !foreign_key ? "#{Owner.table_name}_id" : foreign_key
  end

  def all
    if Target.has_index?(@foreign_key)
      Target.get_all([owner.id], index: @foreign_key)
    else
      Target.where({"#{foreign_key}" => owner.id})
    end
  end

  def where(**attrs)
    attrs = attrs.merge({"#{foreign_key}" => owner.id})
    Target.where(**attrs)
  end

  def find(value)
    Target.find(value)
  end

  def find!(value)
    Target.find!(value)
  end

  private getter owner : Owner
  private getter foreign_key : String
end
