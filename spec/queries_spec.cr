require "./spec_helper"

describe RethinkORM::Queries do
  it "#all" do
    BasicModel.clear

    num_documents = 5
    num_documents.times { BasicModel.create(name: "Psyduck") }

    models = BasicModel.all.to_a
    models.size.should eq num_documents
    models.all? { |m| m.name == "Psyduck" }.should be_true
  end

  it "#count" do
    BasicModel.clear

    num_documents = 5
    num_documents.times { BasicModel.create(name: "Wheezer") }

    count = BasicModel.count
    count.should be_a(Int32)
    count.should eq num_documents
  end
end
