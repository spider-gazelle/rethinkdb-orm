require "./spec_helper"

describe RethinkORM::Validators do
  context "Unique" do
    Spec.before_each do
      Snowflake.clear
    end

    it "invalidates models with non-unique fields" do
      special_snowflake = Snowflake.create!(shape: "fernlike stellar dendrites", meltiness: 0)
      less_special_snowflake = Snowflake.new(shape: "fernlike stellar dendrites", meltiness: 2)

      special_snowflake.valid?.should be_true
      less_special_snowflake.valid?.should be_false

      less_special_snowflake.errors.first.to_s.should eq "shape should be unique"
    end

    it "validates if the model is the same" do
      special_snowflake = Snowflake.create!(shape: "a super special snowflake", meltiness: 5)
      same_flake = Snowflake.find(special_snowflake.id.not_nil!)

      same_flake.should_not be_nil
      unless same_flake.nil?
        same_flake.meltiness = 1000
        same_flake.valid?.should be_true
      end

      special_snowflake.valid?.should be_true
    end

    it "accepts a transform block for the field" do
      special_snowflake = Snowflake.create!(personality: "GENTLE")

      louder_snowflake = Snowflake.new(personality: "gentle", shape: "square", taste: "weak", vibe: "atrocious")

      special_snowflake.valid?.should be_true
      louder_snowflake.valid?.should be_false

      louder_snowflake.errors.first.to_s.should eq "personality should be unique"
    end

    it "passes scoped fields to transform block" do
      fresh_flake = Snowflake.new(taste: "GREAT", vibe: "rotten")
      fresh_flake.taste.should eq "GREAT"

      fresh_flake.valid?.should be_true
      fresh_flake.taste.should eq "great"
      fresh_flake.save!

      less_fresh = Snowflake.new(taste: "great", vibe: "rotten")
      less_fresh.valid?.should be_false
      less_fresh.errors.first.to_s.should eq "taste should be unique"
    end

    it "passes scoped fields to transform callback" do
      fresh_flake = Snowflake.new(vibe: "AWFUL", size: 123)

      fresh_flake.vibe.should eq "AWFUL"
      fresh_flake.valid?.should be_true
      fresh_flake.vibe.should eq "awful"
      fresh_flake.save!

      less_fresh = Snowflake.new(vibe: "awful", size: 123)
      less_fresh.valid?.should be_false
      less_fresh.errors.first.to_s.should eq "vibe should be unique"
    end
  end
end
