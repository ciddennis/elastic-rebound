module Elastic
  module Rebound
    class Result
      # require 'hashie'

      attr_accessor :hit, :strategy, :cached_objects

      def initialize(strategy)
        @strategy = strategy
        @cached_objects = nil
      end

      def hit=(result)
        @hit = result
      end

      # Retrieve the results from elastic search.
      # @param objects If true this will return an array of object from the database instead of the
      #       elastic search results
      def results(objects = false)

        if objects
          return @cached_objects if @cached_objects
          ids = @hit.hits.hits.collect { |c| c["_id"]}
          objects = @strategy.object_type.camelize.constantize.where("id in (?)", ids).load
          @cached_objects = objects.sort_by { |e| ids.index(e.id) }
        else
          @hit.hits
        end

      end

      def total
        @hit.hits["total"]
      end
    end
  end
end