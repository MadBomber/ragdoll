# frozen_string_literal: true

require "test_helper"
require "tmpdir"

# Runs Database.migrate! against a fake connection; the test itself needs no database.
class DatabaseMigrateTest < Minitest::Test
  PROBE_VERSION = "20990101000000"

  def setup
    @original_verbose = ActiveRecord::Migration.verbose
    super
  end

  def teardown
    ActiveRecord::Migration.verbose = @original_verbose
    super
  end

  def test_migrate_reads_migrations_from_migration_paths
    queries = migrate_with_probe_migration

    assert_equal 1, queries.size, "expected one lookup, got #{queries.inspect}"
    assert_includes queries.first, "'#{PROBE_VERSION}'"
  end

  private

  # Runs migrate! with migration_paths pointing at a directory holding one
  # already-applied probe migration; returns the SQL migrate! looked up
  def migrate_with_probe_migration
    queries = []

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "#{PROBE_VERSION}_probe_migration.rb"),
                 'raise "an applied migration must not be loaded"')

      with_singleton_stub(Ragdoll::Core::Database, :migration_paths, [dir]) do
        with_singleton_stub(ActiveRecord::Base, :connection, recording_connection(queries)) do
          Ragdoll::Core::Database.migrate!
        end
      end
    end

    queries
  rescue ActiveRecord::ConnectionNotDefined
    flunk "migrate! bypassed the stubbed ActiveRecord::Base.connection"
  end

  # A connection whose schema_migrations table exists and reports every
  # version as applied, so migrate! only looks each migration up
  def recording_connection(queries)
    Object.new.tap do |connection|
      connection.define_singleton_method(:table_exists?) { |_name| true }
      connection.define_singleton_method(:select_values) do |sql|
        queries << sql
        ["applied"]
      end
    end
  end

  # Replaces +object+.+name+ with a method returning +value+ for the block
  def with_singleton_stub(object, name, value)
    original = object.method(name)
    begin
      object.define_singleton_method(name) { |*| value }
      yield
    ensure
      object.singleton_class.send(:remove_method, name)
      object.define_singleton_method(name, original) if original.owner == object.singleton_class
    end
  end
end
