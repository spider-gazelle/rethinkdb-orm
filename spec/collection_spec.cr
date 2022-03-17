require "./spec_helper"

module RethinkORM
  describe Collection do
    it "#to_json" do
      car = Car.create!(brand: "Toyota")
      car.persisted?.should be_true

      wheel_ids = Array.new(4) do |v|
        Wheel.new(width: 10 + v).tap do |wheel|
          wheel.car = car
          wheel = wheel.save!
          wheel.persisted?.should be_true
          car.id.should eq wheel.car_id
        end.id.as(String)
      end.sort

      Array(Wheel)
        .from_json(car.wheels.to_json)
        .compact_map(&.id).sort!
        .should eq(wheel_ids)
    end
  end
end
