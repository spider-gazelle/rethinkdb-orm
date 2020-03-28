require "./spec_helper"

describe RethinkORM::Associations do
  describe "independent association" do
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
      parent = Parent.create!(name: "Jah Shaka")

      children = [10, 11, 12].map do |age|
        child = Child.new(age: age)
        child.parent = parent
        child = child.save!
        child.persisted?.should be_true
        parent.id.should eq child.parent_id

        child
      end

      parent.children.where do |q|
        q["age"] < 12
      end.size.should eq 2

      children_found = parent.children.to_a.sort_by { |c| c.age || 0 }
      children_found.should eq children

      parent.destroy
      children.try(&.each(&.destroy))
    end
  end

  describe "dependent associations" do
    it "#belongs_to" do
      programmer = Programmer.create!(name: "SPJ")
      coffee = Coffee.new(temperature: 80)
      coffee.programmer = programmer
      coffee.save

      coffee.persisted?.should be_true
      programmer.persisted?.should be_true

      coffee.programmer.try(&.id).should eq programmer.id
      coffee.destroy

      # Ensure owner association deleted
      Programmer.exists?(programmer.id).should be_false
    end

    it "#has_one" do
      friend = Friend.create(name: "liberty")
      programmer = Programmer.create!(name: "RMS", friend_id: friend.id)

      friend.persisted?.should be_true
      programmer.persisted?.should be_true

      programmer.friend.should eq friend
      programmer.destroy

      # Ensure both owner and dependent deleted
      Friend.exists?(friend.id).should be_false
      Programmer.exists?(programmer.id).should be_false
    end

    it "#has_many" do
      car = Car.create!(brand: "Toyota")
      car.persisted?.should be_true

      wheels = [] of Wheel
      4.times do |v|
        wheel = Wheel.new(width: 10 + v)
        wheel.car = car
        wheel = wheel.save!
        wheel.persisted?.should be_true
        car.id.should eq wheel.car_id
        wheels << wheel
      end

      # Check the associations can be retrieved
      dependent_wheels = car.wheels.to_a.sort_by! { |w| w.width || 0 }
      dependent_wheels.should eq wheels

      car.destroy

      # Ensure that parent has been destroyed
      Car.exists?(car.id).should be_false

      # Ensure no children persist in the db
      car.wheels.to_a.empty?.should be_true
    end
  end

  it "should find association by secondary index" do
    programmer = Programmer.create!(name: "BWK")
    coffee = Coffee.new(temperature: 10)
    coffee.programmer = programmer
    coffee.save

    Coffee.by_programmer_id(programmer.id).first.should eq coffee

    coffee.destroy
    programmer.destroy
  end

  it "should ignore associations when delete is used" do
    parent = Parent.create!(name: "Joe")
    child = Child.create!(age: 29, parent_id: parent.id)

    child.delete
    Child.exists?(child.id).should be_false
    Parent.exists?(parent.id).should be_true

    parent.delete
    Parent.exists?(parent.id).should be_false
  end

  it "should cache associations" do
    parent = Parent.create!(name: "Joe")
    child = Child.create!(age: 29, parent_id: parent.id)

    child.parent!.should eq parent
    parent.delete

    # parent cached event when parent deleted
    child.parent!.should eq parent

    # reload triggers reset of cached associations
    child.reload!
    child.parent.should eq nil
    child.destroy
  end

  describe "association names" do
    it "#has_one" do
      orchard = Orchard.new
      orchard.froot.should be_nil
      orchard.froot_id.should be_nil
    end

    it "#belongs_to" do
      fruit = Fruit.new
      fruit.orchy.should be_nil
      fruit.orchy_id.should be_nil
    end
  end
end
