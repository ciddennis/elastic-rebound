require "elastic/rebound/result"
#
# Extend this class to provide custom search strategy.
#
#
module Elastic
  module Rebound
    class Strategy
      attr_accessor :per_page, :page, :results, :sort, :index_name, :object_type

      def initialize(index_name, object_type)
        @per_page = 25
        @page = 1
        @sort = nil
        @results = nil
        @index_name = index_name
        @object_type = object_type
      end

      def search
        raise Exception.new("Your developer made a mistake or you did and did not use a concrete implementation of this class.  In other words fix your code.")
      end

      def range(field, start_range, end_rage)
        {:range => {field => {:from => start_range, :to => end_rage, :include_lower => true, :include_upper => true}}}
      end

      def simple_field(field, value)
        {:term => {field => value.kind_of?(String) ? Elastic::Rebound.escape_query(value) : value}}
      end

      protected

      # Create a wrapper around the search results. This factory method allows us to set extra vars we might need.
      def create_search_result
        Elastic::Rebound::Result.new(self)
      end
    end
  end
end
