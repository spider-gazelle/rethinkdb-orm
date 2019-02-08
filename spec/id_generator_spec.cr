require "./spec_helper"

describe RethinkORM::IdGenerator do
  pending "generates unique ids" do
    table_name = "heroes"
    ready_channel = Channel(Nil).new

    ids1 = [] of String
    ids2 = [] of String
    ids3 = [] of String
    ids4 = [] of String

    lotsof = 500

    spawn do
      lotsof.times { ids1 << RethinkORM::IdGenerator.next(table_name) }
      ready_channel.send nil
    end

    spawn do
      lotsof.times { ids2 << RethinkORM::IdGenerator.next(table_name) }
      ready_channel.send nil
    end

    spawn do
      lotsof.times { ids3 << RethinkORM::IdGenerator.next(table_name) }
      ready_channel.send nil
    end

    spawn do
      lotsof.times { ids4 << RethinkORM::IdGenerator.next(table_name) }
      ready_channel.send nil
    end

    4.times do
      ready_channel.receive
    end

    combined_ids = (ids1 + ids2 + ids3 + ids4).flatten
    combined_ids.uniq.size.should eq combined_ids.size
  end
end
