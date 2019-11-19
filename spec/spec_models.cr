require "time"

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

class LittleBitPersistent < RethinkORM::Base
  attribute name : String
  attribute age : Int32, persistence: false
end

class ConvertedFields < RethinkORM::Base
  attribute name : String
  attribute time : Time, converter: Time::EpochConverter
end

# Association Models

class Fruit < RethinkORM::Base
  attribute type : String
  belongs_to Orchard, association_name: :orchy
end

class Orchard < RethinkORM::Base
  attribute name : String
  has_one Fruit, association_name: :froot
end

class Car < RethinkORM::Base
  attribute brand : String
  attribute vin : String

  secondary_index :vin
  has_many Wheel, collection_name: "wheels", dependent: :destroy
end

class Wheel < RethinkORM::Base
  attribute width : Int32
  belongs_to Car
end

class Programmer < RethinkORM::Base
  attribute name : String
  has_one Friend, dependent: :destroy
end

class Friend < RethinkORM::Base
  attribute name : String
end

class Coffee < RethinkORM::Base
  attribute temperature : Int32
  belongs_to Programmer, dependent: :destroy
end

class Parent < RethinkORM::Base
  attribute name : String
  has_many Child, collection_name: "children"
end

class Child < RethinkORM::Base
  attribute age : Int32
  has_one Dog
  belongs_to Parent
end

class Dog < RethinkORM::Base
  attribute breed : String
  belongs_to Child
end

class UnneccesarilyLongNameThatWillProduceAStupidTableName < RethinkORM::Base
  table :mod
  attribute why : String
end

# Query model
class Tree < RethinkORM::Base
  attribute roots : Array(String) = ->{ [] of String }

  def self.by_root_id(id)
    Tree.raw_query do |q|
      q.table(Tree.table_name).filter do |doc|
        doc["roots"].contains(id)
      end
    end
  end
end

class Root < RethinkORM::Base
  attribute length : Float32
end

# Validation models

class Snowflake < RethinkORM::Base
  attribute shape : String
  attribute meltiness : Int32
  attribute personality : String
  attribute taste : String
  attribute vibe : String
  attribute size : Int32

  ensure_unique :meltiness
  ensure_unique :shape, callback: :id
  ensure_unique :personality do |personality|
    personality.downcase
  end

  ensure_unique scope: [:taste, :vibe], field: :taste do |taste, vibe|
    {taste.downcase, vibe.downcase}
  end

  ensure_unique scope: [:vibe, :size], field: :vibe, callback: :dip

  def dip(vibe : String, size : Int32)
    {vibe.downcase, size}
  end

  def id(value : T) forall T
    value
  end
end

# Timestamps

class Timo < RethinkORM::Base
  include RethinkORM::Timestamps

  attribute name : String
end
