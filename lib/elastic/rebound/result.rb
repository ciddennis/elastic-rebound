module Elastic
  module Rebound
    require 'ostruct'

    class DeepStruct < OpenStruct
      def initialize(hash=nil)
        @table = {}
        @hash_table = {}

        if hash
          hash.each do |k,v|
            @table[k.to_sym] = (v.is_a?(Hash) ? self.class.new(v) : v)
            @hash_table[k.to_sym] = v

            new_ostruct_member(k)
          end
        end
      end

      def to_h
        @hash_table
      end

    end

    class Result
      # require 'hashie'

      attr_accessor :hit, :strategy, :cached_objects

      def initialize(strategy)
        @strategy = strategy
        @cached_objects = nil
      end

      def hit=(result)
        @hit = DeepStruct.new(result)
      end

      # Retrieve the results from elastic search.
      # @param objects If true this will return an array of object from the database instead of the
      #       elastic search results
      def results(objects = false)

        if objects
          return @cached_objects if @cached_objects
          ids = @hit.hits.hits.map(&:_id)
          objects = @strategy.object_type.camelize.constantize.where("id in (?)", ids).load
          @cached_objects = objects.sort_by { |e| ids.index(e.id) }
        else
          @hit.hits
        end

      end

      def total
        @hit.hits.total
      end
    end
  end
end