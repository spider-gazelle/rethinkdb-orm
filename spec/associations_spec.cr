describe RethinkORM::Associations do
  it "should create associations" do
    parent = Parent.create!(name: "joe")
    child = Child.create!(age: 29, parent_id: parent.id)

    parent.persisted?.should be_true
    child.persisted?.should be_true
    parent.id.should eq child.parent_id

    child_found = Child.where(parent_id: child.parent_id)[0]?
    child_found.should eq child

    child.destroy
    parent.destroy
  end

  it "should allow setting of parent in belongs_to relationships" do
    parent = Parent.create!(name: "joe")
    child = Child.new(age: 29)
    child.parent = parent
    child.save

    parent.persisted?.should be_true
    child.persisted?.should be_true
    parent.id.should eq child.parent_id

    child_found = Child.where(parent_id: child.parent_id)[0]?
    child_found.should eq child

    child.destroy
    parent.destroy
  end

  it "should allow querying for dependent children" do
    parent = Parent.create!(name: "joe")
    child1 = Child.new(age: 20)
    child2 = Child.new(age: 21)
    child3 = Child.new(age: 22)
    children = [child1, child2, child3]

    children.each do |c|
      c.parent = parent
      c.save
      c.persisted?.should be_true
    end

    parent.persisted?.should be_true
    parent.children.sort_by { |c| c.age || 0 }.should eq children

    found_children = Child.where(parent_id: parent.id)
    found_children.sort_by { |c| c.age || 0 }.should eq children

    children.each { |c| c.destroy }
    parent.destroy
  end

  pending "should work with dependent associations" do
    parent = Parent.create!(name: "joe")
    child = Child.create!(age: 29, parent_id: parent.id)

    parent.persisted?.should be_true
    child.persisted?.should be_true
    id = parent.id

    child.destroy
    child.destroyed?.should be_true
    parent.destroyed?.should be_false

    # Ensure that parent has been destroyed
    expect_raises RethinkORM::Error::DocumentNotFound{Parent.find!(id)}
    expect_raises RethinkORM::Error::DocumentNotFound{parent.reload}

    # Save will always return true unless the model is changed (won't touch the database)
    parent.name = "should fail"

    expect_raises RethinkORM::Error::DocumentNotFound{parent.save}
    expect_raises RethinkORM::Error::DocumentNotFound{parent.save!}
  end

  pending "should cache associations" do
    parent = Parent.create!(name: "joe")
    child = Child.create!(age: 29, parent_id: parent.id)

    id = child.parent.id
    parent.id.should_not eq child.parent.id
    parent.should eq child.parent
    child.parent.id.should eq id

    child.reload

    parent.should eq child.parent
    child.parent.id.should_not eq id

    child.destroy
  end

  pending "should ignore associations when delete is used" do
    parent = Parent.create!(name: "joe")
    child = Child.create!(age: 29, parent_id: parent.id)

    id = child.id
    child.delete

    Child.exists?(id).should be_false
    Parent.exists?(parent.id).should be_true

    id = parent.id
    parent.delete
    Parent.exists?(id).should be_false
  end
end
