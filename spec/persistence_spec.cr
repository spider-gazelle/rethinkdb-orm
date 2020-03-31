require "./spec_helper"

describe RethinkORM::Persistence do
  it "#save" do
    model = BasicModel.new

    model.new_record?.should be_true
    model.destroyed?.should be_false
    model.persisted?.should be_false

    model.age = 34
    model.name = "bob"
    model.address = "somewhere"

    model.new_record?.should be_true
    model.destroyed?.should be_false
    model.persisted?.should be_false

    model.save.should be_true

    model.persisted?.should be_true
    model.new_record?.should be_false
    model.destroyed?.should be_false

    loaded_model = BasicModel.find(model.id.not_nil!)
    loaded_model.should eq model

    model.destroy
    model.new_record?.should be_false
    model.destroyed?.should be_true
    model.persisted?.should be_false
  end

  it "#update" do
    model = BasicModel.new
    model.update(name: "bob", age: 34)

    model.new_record?.should be_false
    model.destroyed?.should be_false
    model.persisted?.should be_true

    model.name.should eq "bob"
    model.age.should eq 34
    model.address.should eq nil

    model.destroy
    model.destroyed?.should be_true
  end

  it "#destroy" do
    model = BasicModel.new(age: 34, name: "bob", address: "somewhere")

    model.new_record?.should be_true
    model.destroyed?.should be_false
    model.persisted?.should be_false

    model.save.should be_true

    model.persisted?.should be_true
    model.new_record?.should be_false
    model.destroyed?.should be_false

    loaded_model = BasicModel.find(model.id.not_nil!)
    loaded_model.should eq model

    model.destroy
    model.new_record?.should be_false
    model.destroyed?.should be_true
    model.persisted?.should be_false

    BasicModel.exists?(model.id.not_nil!).should be_false
  end

  it "#reload!" do
    model = BasicModel.new

    model.name = "bob"
    model.address = "somewhere"
    model.age = 34

    model.save.should be_true
    id = model.id
    model.name = nil
    model.changed?.should be_true

    model_copy = BasicModel.find!(model.id.not_nil!)
    model_copy.name = "bill"
    model_copy.save!

    model.reload!

    model.changed?.should be_false

    model.id.should eq id
    model.name.should eq "bill"

    model.destroy
  end

  it "#clear" do
    BasicModel.clear

    name = "Wobbuffet"
    5.times do
      BasicModel.create(name: name)
    end

    models = BasicModel.all.to_a
    models.size.should eq 5
    models.all? { |m| m.name == name }.should be_true

    BasicModel.clear
    BasicModel.count.should eq 0
  end

  it "should save/load fields with converters" do
    time = Time.unix(rand(1000000))
    model = ConvertedFields.create!(name: "gremlin", time: time)
    loaded = ConvertedFields.find!(model.id.not_nil!)

    loaded.time.should eq model.time
  end

  it "saves a model with defaults" do
    model = ModelWithDefaults.new

    model.name.should eq "bob"
    model.age.should eq 23
    model.address.should eq nil

    model.new_record?.should be_true
    model.destroyed?.should be_false
    model.persisted?.should be_false

    model.save.should be_true

    model.new_record?.should be_false
    model.destroyed?.should be_false
    model.persisted?.should be_true

    loaded_model = ModelWithDefaults.find(model.id.not_nil!)
    loaded_model.should eq model

    model.destroy
    model.new_record?.should be_false
    model.destroyed?.should be_true
    model.persisted?.should be_false
  end

  it "performs validations" do
    model = ModelWithValidations.new

    model.valid?.should be_false

    # Test create
    result = model.save
    result.should be_false
    model.errors.size.should eq 2

    expect_raises(RethinkORM::Error::DocumentInvalid) do
      model.save!
    end

    model.name = "bob"
    model.age = 23
    model.valid?.should be_true
    model.save.should be_true

    # Test update
    model.name = nil
    model.valid?.should be_false
    model.save.should be_false
    expect_raises(RethinkORM::Error::DocumentInvalid) do
      model.save!
    end

    model.age = 23
    model.name = "joe"
    model.valid?.should be_true
    model.save!.should eq model

    model.destroy
  end

  it "persists only persisted attributes" do
    model = LittleBitPersistent.create!(name: "Johnny Johnny", age: 100)

    loaded_model = LittleBitPersistent.find(model.id.not_nil!)
    loaded_model.should_not eq nil
    if loaded_model
      loaded_model.age.should eq nil
      loaded_model.should_not eq model
      loaded_model.persistent_attributes.should eq model.persistent_attributes
    end

    model.destroy
  end

  describe "callbacks" do
    it "execute callbacks" do
      model = ModelWithCallbacks.new

      # Test initialize
      model.name.should eq nil
      model.age.should eq 10
      model.address.should eq nil

      model.new_record?.should be_true
      model.destroyed?.should be_false
      model.persisted?.should be_false

      # Test create
      model.save.should be_true

      model.name.should eq "bob"
      model.age.should eq 10
      model.address.should eq "23"

      # Test Update
      model.address = "other"
      model.address.should eq "other"
      model.save.should be_true

      model.name.should eq "bob"
      model.age.should eq 30
      model.address.should eq "23"

      # Test destroy
      model.destroy
      model.new_record?.should be_false
      model.destroyed?.should be_true
      model.persisted?.should be_false

      model.name.should eq "joe"
    end

    it "skips destroy callbacks on delete" do
      model = ModelWithCallbacks.new

      # Test initialize
      model.name.should eq nil
      model.age.should eq 10
      model.address.should eq nil

      model.new_record?.should be_true
      model.destroyed?.should be_false
      model.persisted?.should be_false

      # Test create
      model.save.should be_true

      # Test delete
      model.delete
      model.new_record?.should be_false
      model.destroyed?.should be_true
      model.persisted?.should be_false

      model.name.should eq "bob"
    end

    it "skips callbacks when updating fields" do
      model = ModelWithCallbacks.new

      # Test initialize
      model.name.should eq nil
      model.age.should eq 10
      model.address.should eq nil

      model.new_record?.should be_true
      model.destroyed?.should be_false
      model.persisted?.should be_false

      # Test create
      result = model.save
      result.should be_true

      model.name.should eq "bob"
      model.age.should eq 10
      model.address.should eq "23"

      # Test Update
      model.update_fields(address: "other")
      model.address.should eq "other"
      loaded = ModelWithCallbacks.find(model.id.not_nil!)
      loaded.try(&.address).should eq "other"

      # Test delete skipping callbacks
      model.delete
      model.new_record?.should be_false
      model.destroyed?.should be_true
      model.persisted?.should be_false

      model.name.should eq "bob"
    end
  end
end
