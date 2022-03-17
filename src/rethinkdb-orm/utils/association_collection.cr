require "../index"

class RethinkORM::AssociationCollection(Owner, Target)
  include Enumerable(Target)

  private getter owner : Owner
  private getter foreign_key : String

  delegate :find, :find!, to: Target

  delegate :each, :to_yaml, :to_json, to: :all

  def initialize(@owner, foreign_key = nil)
    @foreign_key = !foreign_key ? "#{Owner.table_name}_id" : foreign_key.to_s
  end

  def all
    if Target.has_index?(foreign_key)
      Target.find_all([owner.id.as(String)], index: foreign_key)
    else
      Target.where({"#{foreign_key}" => owner.id.as(String)})
    end
  end

  # Filter associated documents
  #
  def where(**attrs)
    Target.collection_query do |q|
      index_query = q.get_all([owner.id], index: foreign_key)

      attrs_hash = attrs.to_h
      attrs_hash.empty? ? index_query : index_query.filter(attrs_hash)
    end
  end

  # :ditto:
  def where(**attrs)
    Target.collection_query do |q|
      index_query = q.get_all([owner.id], index: foreign_key)

      attrs_hash = attrs.to_h
      attribute_filtered = attrs_hash.empty? ? index_query : index_query.filter(attrs_hash)

      attribute_filtered.filter { |t| yield t }
    end
  end
end
