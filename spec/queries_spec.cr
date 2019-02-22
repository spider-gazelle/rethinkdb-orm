require "./spec_helper"

describe RethinkORM::Queries do
  it "#all" do
    BasicModel.clear

    5.times do
      BasicModel.create(name: "Psyduck")
    end

    models = BasicModel.all.to_a
    models.size.should eq 5
    models.all? { |m| m.name == "Psyduck" }.should be_true
    BasicModel.clear
  end
end
