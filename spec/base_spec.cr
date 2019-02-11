require "./spec_helper"

class BaseTest < RethinkORM::Base
  attribute name : String
end

class CompareTest < RethinkORM::Base
  attribute age : Int32
end

describe RethinkORM::Base do
  it "should be comparable to other objects" do
    base = BaseTest.create(name: "joe")
    base1 = BaseTest.create(name: "joe")

    base.should eq base
    base.should be base

    base.should_not eq base1

    same_base = BaseTest.find(base.id)
    base.should eq same_base
    base.should_not be same_base
    base1.should_not eq same_base

    base.destroy
    base1.destroy
  end

  it "should load database responses" do
    base = BaseTest.create(name: "joe")

    base_found = BaseTest.find!(base.id)

    base_found.id.should eq base.id
    base_found.should eq base
    base_found.should_not be base
    base.destroy
  end

  it "should support serialisation" do
    base = BaseTest.create(name: "joe")
    base_id = base.id
    base.to_json.should eq ({name: "joe", id: base_id}.to_json)

    base.destroy
  end

  it "should support dirty attributes" do
    begin
      base = BaseTest.new
      base.changed_attributes.empty?.should be_true

      base.name = "change"
      base.changed_attributes.empty?.should be_false

      base = BaseTest.new(name: "bob")
      base.changed_attributes.empty?.should be_false

      # A saved model should have no changes
      base = BaseTest.create(name: "joe")
      base.changed_attributes.empty?.should be_true
    ensure
      base.destroy if base && base.id
    end
  end
end
