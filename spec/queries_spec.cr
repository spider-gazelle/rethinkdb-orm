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

  it "#raw_query" do
    tree1 = Tree.new
    tree2 = Tree.new

    roots = 3.times.to_a.compact_map do
      Root.create!(length: (rand * 10).to_f32).id
    end

    # Check all roots created
    roots.size.should eq 3

    tree1.roots = roots[0..1]
    tree2.roots = roots[1..2]

    tree1.save
    tree2.save

    tree_ids = [tree1.id, tree2.id].compact

    get_tree_ids = ->(root_id : String) {
      # Refer to ./spec_models for `Tree#by_root_id` query
      Tree.by_root_id(root_id).to_a.compact_map(&.id).sort
    }

    # Check the correct
    get_tree_ids.call(roots[0]).should eq [tree_ids[0]]
    get_tree_ids.call(roots[1]).should eq tree_ids.sort
    get_tree_ids.call(roots[2]).should eq [tree_ids[1]]
  end
end
