# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaDumper < ConnectionAdapters::SchemaDumper # :nodoc:
        private
          def extensions(stream)
            extensions = @connection.extensions
            if extensions.any?
              stream.puts "  # These are extensions that must be enabled in order to support this database"
              extensions.sort.each do |extension|
                stream.puts "  enable_extension #{extension.inspect}"
              end
              stream.puts
            end
          end

          def types(stream)
            types = @connection.enum_types
            if types.any?
              stream.puts "  # Custom types defined in this database."
              stream.puts "  # Note that some types may not work with other database engines. Be careful if changing database."
              types.sort.each do |name, values|
                stream.puts "  create_enum #{name.inspect}, #{values.split(",").inspect}"
              end
              stream.puts
            end
          end

          def exclusion_constraints_in_create(table, stream)
            if (exclusion_constraints = @connection.exclusion_constraints(table)).any?
              add_exclusion_constraint_statements = exclusion_constraints.map do |exclusion_constraint|
                parts = [
                  "t.exclusion_constraint #{exclusion_constraint.expression.inspect}"
                ]

                parts << "where: #{exclusion_constraint.where.inspect}" if exclusion_constraint.where
                parts << "using: #{exclusion_constraint.using.inspect}" if exclusion_constraint.using

                if exclusion_constraint.export_name_on_schema_dump?
                  parts << "name: #{exclusion_constraint.name.inspect}"
                end

                "    #{parts.join(', ')}"
              end

              stream.puts add_exclusion_constraint_statements.sort.join("\n")
            end
          end

          def unique_keys_in_create(table, stream)
            if (unique_keys = @connection.unique_keys(table)).any?
              add_unique_key_statements = unique_keys.map do |unique_key|
                parts = [
                  "t.unique_key #{unique_key.columns.inspect}"
                ]

                parts << "deferrable: #{unique_key.deferrable.inspect}" unless unique_key.deferrable == false

                if unique_key.export_name_on_schema_dump?
                  parts << "name: #{unique_key.name.inspect}"
                end

                "    #{parts.join(', ')}"
              end

              stream.puts add_unique_key_statements.sort.join("\n")
            end
          end

          def prepare_column_options(column)
            spec = super
            spec[:array] = "true" if column.array?

            if @connection.supports_virtual_columns? && column.virtual?
              spec[:as] = extract_expression_for_virtual_column(column)
              spec[:stored] = true
              spec = { type: schema_type(column).inspect }.merge!(spec)
            end

            spec[:enum_type] = "\"#{column.sql_type}\"" if column.enum?

            spec
          end

          def default_primary_key?(column)
            schema_type(column) == :bigserial
          end

          def explicit_primary_key_default?(column)
            column.type == :uuid || (column.type == :integer && !column.serial?)
          end

          def schema_type(column)
            return super unless column.serial?

            if column.bigint?
              :bigserial
            else
              :serial
            end
          end

          def schema_expression(column)
            super unless column.serial?
          end

          def extract_expression_for_virtual_column(column)
            column.default_function.inspect
          end
      end
    end
  end
end
