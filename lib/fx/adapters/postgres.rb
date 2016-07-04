module Fx
  # F(x) database adapters.
  #
  # F(x) ships with a Postgres adapter only but can be extended with
  # additional adapters. The {Fx::Adapters::Postgres} adapter provides the
  # interface.
  module Adapters
    # An adapter for managing Postgres triggers and functions.
    #
    # These methods are used interally by F(x) and are not intended for direct
    # use. Methods that alter database schema are intended to be called via
    # {Fx::Schema::Statements}.
    #
    # The methods are documented here for insight into specifics of how F(x)
    # integrates with Postgres and the responsibilities of {Fx::Adapters}.
    module Postgres
      # The SQL query used by F(x) to retrieve the functions considered dumpable
      # into `db/schema.rb`.
      FUNCTIONS_WITH_DEFINITIONS_QUERY = <<~SQL
        SELECT
            pp.proname AS name,
            pg_get_functiondef(pp.oid) AS definition
        FROM pg_proc pp
        INNER JOIN pg_namespace pn
            ON (pn.oid = pp.pronamespace)
        INNER JOIN pg_language pl
            ON (pl.oid = pp.prolang)
        WHERE pl.lanname NOT IN ('c','internal')
            AND pn.nspname NOT LIKE 'pg_%'
            AND pn.nspname <> 'information_schema'
      SQL
      # The SQL query used by F(x) to retrieve the triggers considered dumpable
      # into `db/schema.rb`.
      TRIGGERS_WITH_DEFINITIONS_QUERY = <<~SQL
        SELECT
            pt.tgname AS name,
            pg_get_triggerdef(pt.oid) AS definition
        FROM pg_trigger pt
      SQL

      # Returns an array of functions in the database.
      #
      # This collection of functions is used by the [Fx::SchemaDumper] to
      # populate the `schema.rb` file.
      #
      # @return [Array<Fx::Function>]
      def self.functions
        execute(FUNCTIONS_WITH_DEFINITIONS_QUERY).
          map { |result| Fx::Function.new(result) }
      end

      # Returns an array of triggers in the database.
      #
      # This collection of triggers is used by the [Fx::SchemaDumper] to
      # populate the `schema.rb` file.
      #
      # @return [Array<Fx::Trigger>]
      def self.triggers
        execute(TRIGGERS_WITH_DEFINITIONS_QUERY).
          map { |result| Fx::Trigger.new(result) }
      end

      # Creates a function in the database.
      #
      # This is typically called in a migration via {Fx::Schema::Statements::Function#create_function}.
      #
      # @param sql_definition The SQL schema for the function.
      #
      # @return [void]
      def self.create_function(sql_definition)
        execute sql_definition
      end

      # Creates a trigger in the database.
      #
      # This is typically called in a migration via {Fx::Schema::Statements::Trigger#create_trigger}.
      #
      # @param sql_definition The SQL schema for the trigger.
      #
      # @return [void]
      def self.create_trigger(sql_definition)
        execute sql_definition
      end

      # Drops the function from the database
      #
      # This is typically called in a migration via {Fx::Schema::Statements::Function#drop_function}.
      #
      # @param name The name of the function to drop
      #
      # @return [void]
      def self.drop_function(name)
        execute "DROP FUNCTION #{name}();"
      end

      # Drops the trigger from the database
      #
      # This is typically called in a migration via {Fx::Schema::Statements::Trigger#drop_trigger}.
      #
      # @param name The name of the trigger to drop
      # @param on The associated table for the trigger to drop
      #
      # @return [void]
      def self.drop_trigger(name, on:)
        execute "DROP TRIGGER #{name} ON #{on};"
      end

      private

      def self.execute(sql, base = ActiveRecord::Base)
        base.connection.execute(sql)
      end
      private_class_method :execute
    end
  end
end
