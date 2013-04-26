module Elastic
  module Rebound
    module ActiveCallback

      def self.included(base)
        base.class_eval do
          index_self = lambda {
            if self.persisted?
              Elastic::Rebound.index(self)
            else
              Elastic::Rebound.unindex(self)
            end
          }

          rollback_self = lambda {
            if self.persisted?
              o = self.class.find_by_id(self.id)
              Elastic::Rebound.index(o)
            else
              Elastic::Rebound.unindex(self)
            end
          }

          after_rollback &rollback_self
          after_commit &index_self

        end
      end

    end
  end
end