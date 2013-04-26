require 'active_record'
require 'elastic/rebound'


class SimpleIndexAdaptor < Elastic::Rebound::Adaptor
  INDEX_NAME = "ss_simple" if !defined?(INDEX_NAME)
  OBJECT_TYPE = "Simple"  if !defined?(OBJECT_TYPE)

  class SimpleSearchStrategy < Elastic::Rebound::SimpleStrategy
    def initialize
      super SimpleIndexAdaptor::INDEX_NAME, SimpleIndexAdaptor::OBJECT_TYPE
    end
  end

  class AllSearchStrategy < Elastic::Rebound::SimpleStrategy
    def initialize
      super SimpleIndexAdaptor::INDEX_NAME, SimpleIndexAdaptor::OBJECT_TYPE
    end

    def search
          query = {:match_all => {}}

          result = create_search_result

          search_options = {:from => 0, :size => 10}
          search_options[:index] = @index_name
          search_options[:type] = @object_type

          result.hit = Elastic::Rebound.client.search({:query => query}, search_options)

          result
        end
  end

  def async?
    true
  end

  def initialize
      super(INDEX_NAME, OBJECT_TYPE)
  end

  def create_index
    reset_index_and_mapping

    settings = {:analysis => {
        :analyzer => {
            :my_analyzer_1 => {
                :tokenizer => "standard",
                :filter => ["standard", "lowercase", "porterStem", "nGram"]
            }
        }
    }
    }

    Elastic::Rebound.client.create_index @index_name, settings
    define_index

  end

  def define_index

    mapping = {
        "_all" => {:enabled => true, :index => :analyzed, :analyzer => :my_analyzer_1},
        :properties => {
            :id => {:type => 'integer', :index => :not_analyzed, :include_in_all => true},
            :title => {
                :type => :multi_field,
                :fields => {
                    :title => {:type => 'string', :index => :analyzed, :analyzer => :my_analyzer_1, :include_in_all => true},
                    :sortable => {:type => 'string', :index => :not_analyzed, :include_in_all => false},
                }
            },
            :description => {:type => 'string', :index => :analyzed, :analyzer => :my_analyzer_1, :include_in_all => true},
            :happens_at => {:type => 'date', :index => :not_analyzed},
        }
    }

    update_mapping(mapping)

  end

  def index_data(indexable)
    data = {
        :id => indexable.id,
        :title => indexable.title,
        :happens_at => indexable.happens_at,
        :description => indexable.description}
    data
  end


end


class Simple < ActiveRecord::Base
  include Elastic::Rebound::ActiveCallback

end