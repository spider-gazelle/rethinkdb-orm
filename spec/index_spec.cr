require "./spec_helper"

describe RethinkORM::Index do
  it "creates secondary indexes" do
    Car.create!(brand: "Lotus", vin: "YX-Y242069")

    result = RethinkORM::Connection.raw do |q|
      q.db(DB_NAME).table("car").index_list
    end

    result.as_a.should contain "vin"
  end
end
