module Elastic
  module Rebound
    class Result

      attr_accessor :hit, :strategy, :cached_objects

      def initialize(strategy)
        @strategy = strategy
        @cached_objects = nil
      end

      # Retrieve the results from elastic search.
      # @param objects If true this will return an array of object from the database instead of the
      #       elastic search results
      def results(objects = false)

        if objects
          return @cached_objects if @cached_objects
          ids = @hit.hits.map(&:id)
          objects = @strategy.object_type.camelize.constantize.where("id in (?)", ids)
          @cached_objects = objects.sort_by { |e| ids.index(e.id) }
        else
          @hit.hits
        end

      end

      def total
        @hit.total_count
      end
    end
  end
end