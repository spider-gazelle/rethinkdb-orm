require "./spec_helper"

describe RethinkORM::Persistence do
  pending "should save a model" do
    model = BasicModel.new

    model.new_record?.should eq_true
    (model.destroyed?).should eq_false
    (model.persisted?).should eq_false

    model.name = "bob"
    (model.name).should eq "bob"

    model.address = "somewhere"
    model.age = 34

    (model.new_record?).should eq_true
    (model.destroyed?).should eq_false
    (model.persisted?).should eq_false

    result = model.save
    (result).should eq_true

    (model.new_record?).should eq_false
    (model.destroyed?).should eq_false
    (model.persisted?).should eq_true

    model.destroy
    (model.new_record?).should eq_false
    (model.destroyed?).should eq_true
    (model.persisted?).should eq_false
  end

  pending "should save a model with defaults" do
    model = ModelWithDefaults.new

    (model.name).should eq "bob"
    (model.age).should eq 23
    (model.address).should eq nil

    (model.new_record?).should eq_true
    (model.destroyed?).should eq_false
    (model.persisted?).should eq_false

    result = model.save
    (result).should eq_true

    (model.new_record?).should eq_false
    (model.destroyed?).should eq_false
    (model.persisted?).should eq_true

    model.destroy
    (model.new_record?).should eq_false
    (model.destroyed?).should eq_true
    (model.persisted?).should eq_false
  end

  pending "should execute callbacks" do
    model = ModelWithCallbacks.new

    # Test initialize
    (model.name).should eq nil
    (model.age).should eq 10
    (model.address).should eq nil

    (model.new_record?).should eq_true
    (model.destroyed?).should eq_false
    (model.persisted?).should eq_false

    # Test create
    result = model.save
    (result).should eq_true

    (model.name).should eq "bob"
    (model.age).should eq 10
    (model.address).should eq "23"

    # Test Update
    model.address = "other"
    (model.address).should eq "other"
    model.save

    (model.name).should eq "bob"
    (model.age).should eq 30
    (model.address).should eq "23"

    # Test destroy
    model.destroy
    (model.new_record?).should eq_false
    (model.destroyed?).should eq_true
    (model.persisted?).should eq_false

    (model.name).should eq "joe"
  end

  pending "should skip callbacks when updating columns" do
    model = ModelWithCallbacks.new

    # Test initialize
    (model.name).should eq nil
    (model.age).should eq 10
    (model.address).should eq nil

    (model.new_record?).should eq_true
    (model.destroyed?).should eq_false
    (model.persisted?).should eq_false

    # Test create
    result = model.save
    (result).should eq_true

    (model.name).should eq "bob"
    (model.age).should eq 10
    (model.address).should eq "23"

    # Test Update
    model.update_columns(address: "other")
    (model.address).should eq "other"
    loaded = ModelWithCallbacks.find model.id
    (loaded.address).should eq "other"

    # Test delete skipping callbacks
    model.delete
    (model.new_record?).should eq_false
    (model.destroyed?).should eq_true
    (model.persisted?).should eq_false

    (model.name).should eq "bob"
  end

  pending "should perform validations" do
    model = ModelWithValidations.new

    (model.valid?).should eq_false

    # Test create
    result = model.save
    (result).should eq_false
    (model.errors.count).should eq 2

    begin
      model.save!
    rescue e : RethinkORM::Error::RecordInvalid
      (e.record).should eq model
    end

    model.name = "bob"
    model.age = 23
    (model.valid?).should eq_true
    (model.save).should eq_true

    # Test update
    model.name = nil
    (model.valid?).should eq_false
    (model.save).should eq_false
    begin
      model.save!
    rescue e : RethinkORM::Error::RecordInvalid
      (e.record).should eq model
    end

    model.age = "23" # This value will be coerced
    model.name = "joe"
    (model.valid?).should eq_true
    (model.save!).should eq model

    # coercion will fail here
    begin
      model.age = "a23"
      (false).should eq_true
    rescue e : ArgumentError
    end

    model.destroy
  end

  pending "should reload a model" do
    model = BasicModel.new

    model.name = "bob"
    model.address = "somewhere"
    model.age = 34

    (model.save).should eq_true
    id = model.id
    model.name = nil
    (model.changed?).should eq_true

    model.reload
    (model.changed?).should eq_false
    (model.id).should eq id

    model.destroy
    (model.destroyed?).should eq_true
  end

  pending "should update attributes" do
    model = BasicModel.new

    model.name = "bob"
    model.age = 34

    (model.new_record?).should eq_false
    (model.destroyed?).should eq_false
    (model.persisted?).should eq_true

    (model.name).should eq "bob"
    (model.age).should eq 34
    (model.address).should eq nil

    model.destroy
    (model.destroyed?).should eq_true
  end
end
