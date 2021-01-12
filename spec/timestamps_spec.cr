require "timecop"

require "./spec_helper"

describe RethinkORM::Timestamps do
  it "sets created_at upon creation" do
    model = Timo.create!(name: "Timooooo")

    model.created_at.should be_a(Time)
    model.updated_at.should be_a(Time)
    model.created_at.should eq model.updated_at
    model.created_at.should be < Time.utc

    model.destroy
  end

  it "sets updated_at upon update" do
    model = Timo.new(name: "Timooooo")
    Timecop.freeze(1.day.ago) do
      model.save!
    end

    model.created_at.should be_a(Time)
    model.updated_at.should be_a(Time)
    model.created_at.should eq model.updated_at

    model.name = "Timooooo?"
    model.save

    model.updated_at.should_not eq model.created_at
    model.updated_at.should be > model.created_at

    found_model = Timo.find!(model.id.as(String))
    found_model.updated_at.should be_close(model.updated_at, delta: Time::Span.new(seconds: 1, nanoseconds: 0))
    found_model.updated_at.should_not be_close(model.created_at, delta: Time::Span.new(seconds: 1, nanoseconds: 0))

    model.destroy
  end
end
