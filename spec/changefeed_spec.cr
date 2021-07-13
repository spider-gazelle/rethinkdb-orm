require "./spec_helper"

module RethinkORM
  describe Changefeed do
    it "should iterate changes on a single document" do
      base = BasicModel.create!(name: "ren")
      coordination = Channel(Nil).new
      changefeed = BasicModel.changes(base.id)
      events = [] of RethinkORM::Changefeed::Event
      changes = [] of Hash(Symbol, String | Int32 | Hash(String, String) | Nil)

      spawn do
        changefeed.each do |change|
          events << change.event
          changed = change.value.try(&.changed_attributes)
          changes << changed if changed
          coordination.send nil
          break
        end
      end

      base.name = "stimpy"
      base.save

      coordination.receive
      changes.should eq [{:name => "stimpy"}]

      changefeed.stop
    end

    it "should iterate changes on a table" do
      finished_channel = Channel(Nil).new
      changefeed = BasicModel.changes

      names = [] of String | Nil
      events = [] of RethinkORM::Changefeed::Event

      spawn do
        changefeed.each.with_index do |change, index|
          case index
          when 0, 1, 2, 4, 5
            events << change.event
            names << change.value.name
          when 3
            events << change.event
            finished_channel.send nil
            break
          else
            raise "unexpected index #{index}"
          end
        end
      end

      Fiber.yield

      BasicModel.create!(name: "ren")
      BasicModel.create!(name: "stimpy")
      horse = BasicModel.create!(name: "mr. horse")
      horse.destroy

      finished_channel.receive
      changefeed.stop

      BasicModel.create!(name: "bubbles")

      names.should eq ["ren", "stimpy", "mr. horse"]
      events.should eq ([
        RethinkORM::Changefeed::Event::Created,
        RethinkORM::Changefeed::Event::Created,
        RethinkORM::Changefeed::Event::Created,
        RethinkORM::Changefeed::Event::Deleted,
      ])
    end

    describe Changefeed::Raw do
      it "should iterate raw changes on a document" do
        base = BasicModel.create!(name: "ren")
        coordination = Channel(Nil).new
        changefeed = BasicModel.raw_changes(base.id)

        events = [] of Changefeed::Event
        documents = [] of String

        spawn do
          changefeed.each do |change|
            events << change.event
            changed = change.value
            documents << changed if changed
            coordination.send nil
            break
          end
        end

        base.name = "stimpy"
        base.save

        updated_json = JSON.parse base.to_json

        coordination.receive
        changefeed_json = JSON.parse documents.first

        changefeed_json.should eq updated_json
      end

      it "should iterate raw changes on a table" do
        finished_channel = Channel(Nil).new
        changefeed = BasicModel.raw_changes

        events = [] of RethinkORM::Changefeed::Event
        documents = [] of Hash(String, JSON::Any)
        spawn do
          changefeed.each.with_index do |change, index|
            case index
            when 0, 1, 2, 4, 5
              events << change.event
              documents << JSON.parse(change.value).as_h
            when 3
              events << change.event
              finished_channel.send nil
            else
              raise "unexpected index #{index}"
            end
          end
        end

        first = BasicModel.create!(name: "ren")
        second = BasicModel.create!(name: "stimpy")
        third = BasicModel.create!(name: "mr. horse")
        third.destroy
        finished_channel.receive
        changefeed.stop
        second.destroy
        third.destroy

        documents.should eq [first, second, third].map { |model| JSON.parse(model.to_json).as_h }
        events.should eq ([
          RethinkORM::Changefeed::Event::Created,
          RethinkORM::Changefeed::Event::Created,
          RethinkORM::Changefeed::Event::Created,
          RethinkORM::Changefeed::Event::Deleted,
        ])
      end
    end
  end
end
