require "../src/rethinkdb-orm/*"
require "../src/rethinkdb-orm/**"

class BasicModel < RethinkORM::Base
  attribute name : String
  attribute address : String
  attribute age : Int32
end

class ModelWithDefaults < RethinkORM::Base
  attribute name : String = "bob"
  attribute address : String
  attribute age : Int32 = 23
end

class ModelWithCallbacks < RethinkORM::Base
  attribute name : String
  attribute address : String
  attribute age : Int32 = 10

  before_create :update_name
  before_save :set_address
  before_update :set_age

  before_destroy do
    self.name = "joe"
  end

  def update_name
    self.name = "bob"
  end

  def set_address
    self.address = "23"
  end

  def set_age
    self.age = 30
  end
end

class ModelWithValidations < RethinkORM::Base
  attribute name : String
  attribute address : String
  attribute age : Int32 = 10

  validates :name, presence: true
  validates :age, numericality: {greater_than: 20}
end

# # Association Models

class ParentHasMany < RethinkORM::Base
  attribute name : String
  has_many ChildBelongs, plural: "Children"
end

class ParentHasManyDependent < RethinkORM::Base
  attribute name : String
  has_many ChildBelongs, plural: "Children", dependent: RethinkORM::Associations::Destroy
end

class Child < RethinkORM::Base
  attribute age : Int32
  has_one Dog
  belongs_to ParentHasMany
end

class ChildBelongs < RethinkORM::Base
  attribute age : Int32
  belongs_to ParentHasMany
end

class ChildBelongsDependent < RethinkORM::Base
  attribute age : Int32
  belongs_to ParentHasMany, dependent: RethinkORM::Associations::Dependency::Destroy
end

class ChildHasOneDependent < RethinkORM::Base
  attribute age : Int32
  has_one Dog, dependent: RethinkORM::Associations::Dependency::Destroy
end

class Dog < RethinkORM::Base
  attribute breed : String
  belongs_to Child
end

class DogDependent < RethinkORM::Base
  attribute breed : String
  belongs_to Child, dependent: RethinkORM::Associations::Dependency::Destroy
end
