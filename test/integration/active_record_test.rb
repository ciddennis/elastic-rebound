require_relative '../test_helper'
require File.dirname(__FILE__) + '../../models/simple'

class ActiveRecordTest < Test::Unit::TestCase

  def setup
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ":memory:")

    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define(:version => 1) do
      create_table :simples do |t|
        t.string :title
        t.string :description
        t.datetime :happens_at
      end
    end

    Elastic::Rebound.config = {
        :object_types => {
            :Simple => {:active_record => true,
                       :indexers => {
                           SimpleIndexAdaptor => {}
                       }
            }
        },
        :elastic_search_url => "http://localhost:9200"
    }
    Elastic::Rebound.testing_mode(true)

  end

  context "Test ActiveRecord" do

    should "index on save" do
      s = Simple.new(:title => "test title", :description => "test description")
      s.save

      a = SimpleIndexAdaptor::AllSearchStrategy.new
      r = a.search
      assert_equal(1, r.total)
    end

    should "remove object from index on destroy" do
      s = Simple.new(:title => "test title", :description => "test description")
      s.save

      a = SimpleIndexAdaptor::AllSearchStrategy.new
      r = a.search
      assert_equal(1, r.total)

      s.destroy

      a = SimpleIndexAdaptor::AllSearchStrategy.new
      r = a.search
      assert_equal(0, r.total)
    end

    should "trigger async index on save" do

      Elastic::Rebound::IndexJob.stubs(:perform_async)
      Elastic::Rebound::IndexJob.expects(:perform_async).at_least(1)


      Elastic::Rebound.testing_mode(false)
      s = Simple.new(:title => "test title", :description => "test description")
      s.save

    end

    should "trigger async index on destroy" do
      Elastic::Rebound::IndexJob.stubs(:perform_async)
      Elastic::Rebound::IndexJob.expects(:perform_async).at_least(2)

      Elastic::Rebound.testing_mode(false)
      s = Simple.new(:title => "test title", :description => "test description")
      s.save
      s.destroy
    end

    should "Not index because of rollback" do

      Simple.transaction do
        s = Simple.new(:title => "rollbacktest", :description => "test description #{Time.now}")
        s.save
        raise ActiveRecord::Rollback
      end

      a = SimpleIndexAdaptor::AllSearchStrategy.new
      r = a.search
      r.results(true).each do |d|
        assert_not_equal(d.title, "rollbacktest")
      end

    end


    should "return hydrated objects" do
      s = Simple.new(:title => "test title", :description => "test description")
      s.save

      a = SimpleIndexAdaptor::AllSearchStrategy.new
      r = a.search
      assert(r.results(true)[0].kind_of?(Simple))
    end


    should "not delete index because we pass in null" do
      s = Simple.new(:title => "test title", :description => "test description")
      s.save

      a = SimpleIndexAdaptor::AllSearchStrategy.new
      r = a.search
      assert(r.results(true)[0].kind_of?(Simple))

      a2 = SimpleIndexAdaptor.new
      a2.unindex(nil)

      a = SimpleIndexAdaptor::AllSearchStrategy.new
      r = a.search
      assert(r.results(true)[0].kind_of?(Simple))
    end

  end


end
