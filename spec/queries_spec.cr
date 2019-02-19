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

  pending "#changes" do
    it "should iterate changes on a single document" do
      base = BasicModel.create!(name: "ren")
      coordination = Channel(Nil).new
      spawn do
        BasicModel.changes(base.id).each do |model|
          model.name.should eq "stimpy"
          coordination.send nil
          break
        end
      end

      base.update(name: "stimpy")
      coordination.receive
    end

    it "should iterate changes on a table" do
      finished_channel = Channel(Nil).new
      spawn do
        BasicModel.changes.each.with_index do |model, index|
          case index
          when 0
            model.name.should eq "ren"
          when 1
            model.name.should eq "stimpy"
          when 2
            model.name.should eq "mr. horse"
            finished_channel.send nil
            break
          end
        end
      end
      BasicModel.create!(name: "ren")
      BasicModel.create!(name: "stimpy")
      BasicModel.create!(name: "mr. horse")
      finished_channel.receive
    end
  end
end
