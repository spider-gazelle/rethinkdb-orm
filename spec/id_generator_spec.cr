require "./spec_helper"

describe RethinkORM::IdGenerator do
  it "generates unique ids" do
    id_channel = Channel(Array(String)).new
    model = BasicModel.new

    5.times do
      spawn do
        ids = [] of String
        500.times { ids << RethinkORM::IdGenerator.next(model) }
        id_channel.send ids
      end
    end

    combined_ids = [] of String
    5.times do
      combined_ids += id_channel.receive
    end

    combined_ids.uniq.size.should eq combined_ids.size
  end
end
