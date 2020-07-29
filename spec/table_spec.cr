require "./spec_helper"

describe RethinkORM::Table do
  it "produces a table name from the class" do
    model = BasicModel.create!(name: "Wallace")
    id = model.id.as(String)
    id.should start_with "basic_model"
    result = RethinkORM::Connection.raw do |q|
      q.table_list.contains("basic_model")
    end
    result.should be_true
  end

  it "allows overriding of default table name" do
    model = UnneccesarilyLongNameThatWillProduceAStupidTableName.create!(why: "not")
    id = model.id.as(String)
    id.should start_with "mod"
    result = RethinkORM::Connection.raw do |q|
      q.table_list.contains("mod")
    end
    result.should be_true
  end
end
