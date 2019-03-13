require "./spec_helper"

describe RethinkORM::Changefeed do
  it "should iterate changes on a single document" do
    base = BasicModel.create!(name: "ren")
    coordination = Channel(Nil).new
    changefeed = BasicModel.changes(base.id)
    events = [] of RethinkORM::Changefeed::Event
    changes = [] of Hash(Symbol, String | Int32 | Nil)
    ids = [] of String

    spawn do
      changefeed.each do |change|
        events << change[:event]
        changed = change[:value].try(&.changed_attributes)
        changes << changed if changed
        ids << change[:id]
        coordination.send nil
        break
      end
    end

    base.update(name: "stimpy")
    coordination.receive
    changes.should eq [{:name => "stimpy"}]
    ids.all?(base.id).should be_true
  end

  it "should iterate changes on a table" do
    finished_channel = Channel(Nil).new
    changefeed = BasicModel.changes

    names = [] of String
    events = [] of RethinkORM::Changefeed::Event
    spawn do
      changefeed.each.with_index do |change, index|
        case index
        when 0
          events << change[:event]
          new_name = change[:value].try(&.name)
          names << new_name if new_name
        when 1
          events << change[:event]
          new_name = change[:value].try(&.name)
          names << new_name if new_name
        when 2
          events << change[:event]
          new_name = change[:value].try(&.name)
          names << new_name if new_name
        when 3
          events << change[:event]
          finished_channel.send nil
          break
        end
      end
    end

    BasicModel.create!(name: "ren")
    BasicModel.create!(name: "stimpy")
    horse = BasicModel.create!(name: "mr. horse")
    horse.destroy
    finished_channel.receive

    names.should eq ["ren", "stimpy", "mr. horse"]
    events.should eq ([
      RethinkORM::Changefeed::Event::Created,
      RethinkORM::Changefeed::Event::Created,
      RethinkORM::Changefeed::Event::Created,
      RethinkORM::Changefeed::Event::Deleted,
    ])
  end
end
