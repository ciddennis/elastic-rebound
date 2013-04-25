require "elastic/rebound"
require "elastic/rebound/strategy"
require 'lucene'

module Elastic
  module Rebound
    class SimpleStrategy < Elastic::Rebound::Strategy
      attr_accessor :full_text, :must_match, :must_not_match, :full_text_fields, :should_match

      def initialize(index_name, object_type)
        @full_text = nil
        @must_match = []
        @must_not_match = []
        @should_match  = []
        @full_text_fields = ["_all"]
        super(index_name, object_type)
      end

      def search

        query = {
            :filtered => {
                :query => {

                },
                :filter => {
                    :bool => {
                        :must => [],
                        :must_not => [],
                        :should => []
                    }
                }
            }
        }

        # If there is a search text then add it in
        if @full_text.present?
          query[:filtered][:query] = {:multi_match => {:query => Lucene::escape_query(@full_text), :fields => full_text_fields , :operator => "and"} }
        else
          query[:filtered][:query] = {:queryString => {:query => "*"}}
        end

        # Add the  must have match here
        if @must_match.size > 0
          @must_match.each do |item|
            query[:filtered][:filter][:bool][:must] << item
          end
        else
          query[:filtered][:filter][:bool].delete(:must)
        end

        # Add the  should have match here
        if @should_match.size > 0
          @should_match.each do |item|
            query[:filtered][:filter][:bool][:should] << item
          end
        else
          query[:filtered][:filter][:bool].delete(:should)
        end


        # Add the must  NOT have match here
        if @must_not_match.size > 0
          @must_not_match.each do |item|
            query[:filtered][:filter][:bool][:must_not] << item
          end
        else
          query[:filtered][:filter][:bool].delete(:must_not)
        end


        if @must_not_match.size == 0 && @must_match.size == 0
          query[:filtered][:filter][:bool].delete(:must)
        end

        search_options = {:from => (@page) * @per_page, :size => @per_page}
        search_options[:sort] = @sort if @sort

        search_options[:index] = @index_name
        search_options[:type] = @object_type
          #search_options[:explain] = true

        result = create_search_result
        result.hit = Elastic::Rebound.client.search({:query => query}, search_options)

        result
      end
    end
  end
end