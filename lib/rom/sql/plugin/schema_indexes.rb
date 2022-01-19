# frozen_string_literal: true

require "rom/sql/schema/index_dsl"

module ROM
  module SQL
    module Plugin
      module SchemaIndexes
        # @api private
        def self.apply(schema, **)
          indexes = index_dsl.(schema.config.dataset, schema.attributes)

          schema.set(:indexes, indexes)
        end

        # @api public
        module DSL
          # @!attribute [r] index_dsl
          #   @return [IndexDSL] Index DSL instance (created only if indexes block is called)
          attr_reader :index_dsl

          # Define indexes within a block
          #
          # @api public
          def indexes(&block)
            @index_dsl = IndexDSL.new(options, &block)
          end
        end
      end
    end
  end
end
