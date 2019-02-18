require "./spec_helper"

describe RethinkORM::Associations do
  describe "should create association" do
    it "#has_one" do
      dog = Dog.create!(breed: "Dachsund")
      child = Child.create!(age: 29, dog_id: dog.id)

      child.persisted?.should be_true
      dog.persisted?.should be_true

      child.dog_id.should eq dog.id

      # Looks-ups for association
      child.dog.should eq dog

      child.destroy
      dog.destroy
    end

    it "#has_many" do
      parent = ParentHasMany.create!(name: "Jah Shaka")

      children = [10, 11, 12].map do |age|
        child = ChildBelongs.new(age: age)
        child.parent_has_many = parent
        child = child.save!
        child.persisted?.should be_true
        parent.id.should eq child.parent_has_many_id
        child
      end

      children_found = parent.children.to_a.sort_by { |c| c.age || 0 }
      children_found.should eq children

      parent.destroy
      children.try(&.each(&.destroy))
    end
  end

  describe "dependent associations" do
    it "#belongs_to" do
      child = Child.create!(age: 29)
      dog = DogDependent.new(breed: "Dachsund")
      dog.child = child
      dog.save

      child.persisted?.should be_true
      dog.persisted?.should be_true

      dog.child.try(&.id).should eq child.id
      dog.destroy

      # Ensure owner association deleted
      Child.exists?(child.id).should be_false
    end

    it "#has_one" do
      dog = Dog.create!(breed: "Spitz")
      child = ChildHasOneDependent.new(age: 29)
      child.dog = dog
      child.save

      child.persisted?.should be_true
      dog.persisted?.should be_true

      child.dog.should eq dog
      child.destroy

      # Ensure both owner and dependent deleted
      Child.exists?(child.id).should be_false
      Dog.exists?(dog.id).should be_false
    end

    it "#has_many" do
      parent = ParentHasManyDependent.create!(name: "joe")
      parent.persisted?.should be_true

      children = [10, 11, 12].map do |age|
        child = ChildBelongsDependent.new(age: age)
        child.parent_has_many = parent
        child = child.save!
        child.persisted?.should be_true
        parent.id.should eq child.parent_has_many_id
        child
      end

      # Check the associations can be retrieved
      dependent_children = parent.children.to_a.sort_by! { |c| c.age || 0 }
      dependent_children.should eq children

      parent.destroy
      # Ensure that parent has been destroyed
      ParentHasManyDependent.exists?(parent.id).should be_false

      # Ensure no children persist in the db
      parent.children.to_a.empty?.should be_true
    end
  end

  it "should ignore associations when delete is used" do
    parent = ParentHasMany.create!(name: "joe")
    child = ChildBelongsDependent.create!(age: 29, parent_has_many_id: parent.id)

    id = child.id
    child.delete

    ChildBelongsDependent.exists?(id).should be_false
    ParentHasMany.exists?(parent.id).should be_true

    id = parent.id
    parent.delete
    ParentHasMany.exists?(id).should be_false
  end
end
