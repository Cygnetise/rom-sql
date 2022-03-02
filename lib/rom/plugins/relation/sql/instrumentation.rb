# frozen_string_literal: true

module ROM
  module Plugins
    module Relation
      module SQL
        # Instrumentation for relations and commands
        #
        # This plugin allows configuring a notification system, that will be used
        # to instrument interactions with databases, it's based on an abstract API
        # so it should work with any instrumentation object that provides
        # `instrument(identifier, payload)` method.
        #
        # By default, instrumentation is triggered with following arguments:
        #   - `identifier` is set to `:sql`
        #   - `payload` is set to a hash with following keys:
        #     - `:name` database type, ie `:sqlite`, `:postgresql` etc.
        #     - `:query` a string with an SQL statement that was executed
        #
        # @example configuring notifications
        #   config = ROM::Configuration.new(:sqlite, 'sqlite::memory')
        #
        #   config.plugin(:sql, relations: :instrumentation) do |c|
        #     c.notifications = MyNotifications.new
        #   end
        #
        # @api public
        module Instrumentation
          extend Notifications::Listener

          subscribe('configuration.relations.registry.created') do |event|
            registry = event[:registry]

            relations = registry.select { |_, r| r.adapter == :sql && r.respond_to?(:__notifications) }.to_h
            db_notifications = relations.values.map { |r| [r.dataset.db, r.__notifications] }.uniq.to_h

            db_notifications.each do |db, __notifications|
              instrumenter = Instrumenter.new(db.database_type, __notifications)
              db.extend(instrumenter)
            end
          end

          # This stateful module is used to extend database connection objects
          # and monkey-patches `log_connection_yield` method, which unfortunately
          # is the only way to provide instrumentation on the sequel side.
          #
          # @api private
          class Instrumenter < Module
            # @!attribute [r] name
            #   @return [Symbol] database type
            attr_reader :name

            # @!attribute [r] __notifications
            #   @return [Object] any object that responds to `instrument`
            attr_reader :__notifications

            # @api private
            def initialize(name, __notifications)
              @name = name
              @__notifications = __notifications
              define_log_connection_yield
            end

            private

            # @api private
            def define_log_connection_yield
              name = self.name
              __notifications = self.__notifications

              define_method(:log_connection_yield) do |*args, &block|
                __notifications.instrument(:sql, name: name, query: args[0]) do
                  super(*args, &block)
                end
              end
            end
          end

          # Add `:notifications` option to a relation
          #
          # @api private
          def self.included(klass)
            super
            klass.option :__notifications
          end
        end
      end
    end
  end
end

ROM.plugins do
  adapter :sql do
    register :instrumentation, ROM::Plugins::Relation::SQL::Instrumentation, type: :relation
  end
end
