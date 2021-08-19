require "base64"
require "set"
require "./spec_helper"

describe RethinkORM::IdGenerator, focus: true do
  model = BasicModel.new

  it "concats the table name with a 12 char base65 tail" do
    id = RethinkORM::IdGenerator.next(model)
    name, _, tail = id.partition '-'
    name.should eq "basic_model"
    tail.should match /^[0-9A-Za-z-_~]{12}$/
  end

  it "generates unique ids within a single fiber" do
    seq = 10_000
    ids = Set(String).new(initial_capacity: seq)
    seq.times { ids << RethinkORM::IdGenerator.next(model) }
    ids.size.should eq seq
  end

  it "generates unique ids across fibers" do
    ch = Channel(Array(String)).new
    seq = 1000
    fib = 10

    fib.times do
      spawn do
        ch.send Array.new(seq) { RethinkORM::IdGenerator.next(model) }
      end
    end

    ids = Set(String).new
    fib.times { ids.concat ch.receive }

    ids.size.should eq(fib * seq)
  end
end
