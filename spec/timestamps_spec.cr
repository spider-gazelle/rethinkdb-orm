require "./spec_helper"

describe RethinkORM::Timestamps do
  it "sets created_at upon creation" do
    model = Timo.create!(name: "Timooooo")

    model.created_at.should be_a(Time)
    model.updated_at.should be_a(Time)
    model.created_at.not_nil!.should eq model.updated_at.not_nil!
    model.created_at.not_nil!.should be < Time.utc

    model.destroy
  end

  it "sets updated_at upon update" do
    model = Timo.create!(name: "Timooooo")

    model.created_at.should be_a(Time)
    model.updated_at.should be_a(Time)
    model.created_at.not_nil!.should eq model.updated_at

    sleep 2

    model.update(name: "Timooooo?")
    model.updated_at.not_nil!.should_not eq model.created_at
    model.updated_at.not_nil!.should be > model.created_at.not_nil!

    found_model = Timo.find!(model.id.not_nil!)
    found_model.updated_at.not_nil!.should be_close(model.updated_at.not_nil!, delta: Time::Span.new(seconds: 1, nanoseconds: 0))
    found_model.updated_at.not_nil!.should_not be_close(model.created_at.not_nil!, delta: Time::Span.new(seconds: 1, nanoseconds: 0))

    model.destroy
  end
end
