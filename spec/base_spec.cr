require "./spec_helper"

class BaseTest < RethinkOrm::Base
  attribute :name, :job
end

class CompareTest < RethinkOrm::Base
  attribute :age
end

describe RethinkOrm::Base do
  it "should be comparable to other objects" do
    base = BaseTest.create!(name: "joe")
    base2 = BaseTest.create!(name: "joe")
    base3 = BaseTest.create!(ActiveSupport::HashWithIndifferentAccess.new(name: "joe"))

    base.should eq base
    base.should be base
    base.should_not eq base2

    same_base = BaseTest.find base.id
    base.should eq same_base
    base.should_not be same_base
    base2.should_not eq same_base

    base.delete
    base2.delete
    base3.delete
  end

  it "should load database responses" do
    base = BaseTest.create!(name: "joe")
    resp = BaseTest.bucket.get(base.id, extended: true)

    expect(resp.key).to eq base.id

    base_loaded = BaseTest.new(resp)
    expect(base_loaded).to eq base
    expect(base_loaded).not_to be base

    base.destroy
  end

  it "should not load objects if there is a type mismatch" do
    base = BaseTest.create!(name: "joe")
    {CompareTest.find_by_id(base.id)}.should expect_raises(RuntimeError)
    base.destroy
  end

  it "should support serialisation" do
    base = BaseTest.create!(name: "joe")
    base_id = base.id
    base.to_json.should eq ({name: "joe", job: nil, id: base_id}.to_json)
    base.to_json(only: :name).should eq ({name: "joe"}.to_json)

    base.destroy
  end

  it "should support dirty attributes" do
    begin
      base = BaseTest.new
      base.changes.empty?.should be_true
      base.previous_changes.empty?.should be_true

      base.name = "change"
      expect(base.changes.empty?).should be_false

      base = BaseTest.new({name: "bob"})
      expect(base.changes.empty?).should be_false
      expect(base.previous_changes.empty?).should be_true

      # A saved model should have no changes
      base = BaseTest.create!(name: "joe")
      base.changes.empty?.should be_true
      base.previous_changes.empty?.should be_false

      # Attributes are copied from the existing model
      base = BaseTest.new(base)
      base.changes.empty?.should be_false
      base.previous_changes.empty?.should be_true
    ensure
      base.destroy if base.id
    end
  end

  pending "should try to load a model with nothing but an ID" do
    begin
      base = BaseTest.create!(name: "joe")
      obj = RethinkOrm.try_load(base.id)
      obj.should eq base
    ensure
      base.destroy
    end
  end
end
