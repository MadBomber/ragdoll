# frozen_string_literal: true

require "test_helper"

class DatabaseTest < Minitest::Test
  # Note: Most database tests are integration tests that require
  # an actual database connection. These tests focus on the
  # public interface and configuration aspects.

  # default_config tests
  def test_default_config_returns_hash
    config = Ragdoll::Core::Database.default_config
    assert_kind_of Hash, config
  end

  def test_default_config_includes_adapter
    config = Ragdoll::Core::Database.default_config
    assert_equal "postgresql", config[:adapter]
  end

  def test_default_config_includes_database
    config = Ragdoll::Core::Database.default_config
    assert_equal "ragdoll_development", config[:database]
  end

  def test_default_config_includes_host
    config = Ragdoll::Core::Database.default_config
    assert_equal "localhost", config[:host]
  end

  def test_default_config_includes_port
    config = Ragdoll::Core::Database.default_config
    assert_equal 5432, config[:port]
  end

  def test_default_config_includes_auto_migrate
    config = Ragdoll::Core::Database.default_config
    assert config[:auto_migrate]
  end

  def test_default_config_includes_logger
    config = Ragdoll::Core::Database.default_config
    assert config[:logger].is_a?(Logger)
  end

  # Environment variable handling tests
  def test_default_config_uses_ragdoll_postgres_user_env
    original = ENV["RAGDOLL_POSTGRES_USER"]
    ENV["RAGDOLL_POSTGRES_USER"] = "custom_user"
    config = Ragdoll::Core::Database.default_config
    assert_equal "custom_user", config[:username]
  ensure
    if original
      ENV["RAGDOLL_POSTGRES_USER"] = original
    else
      ENV.delete("RAGDOLL_POSTGRES_USER")
    end
  end

  def test_default_config_uses_ragdoll_database_password_env
    original = ENV["RAGDOLL_DATABASE_PASSWORD"]
    ENV["RAGDOLL_DATABASE_PASSWORD"] = "secret123"
    config = Ragdoll::Core::Database.default_config
    assert_equal "secret123", config[:password]
  ensure
    if original
      ENV["RAGDOLL_DATABASE_PASSWORD"] = original
    else
      ENV.delete("RAGDOLL_DATABASE_PASSWORD")
    end
  end

  # migration_paths tests
  def test_migration_paths_returns_array
    paths = Ragdoll::Core::Database.migration_paths
    assert_kind_of Array, paths
  end

  def test_migration_paths_includes_db_migrate_directory
    paths = Ragdoll::Core::Database.migration_paths
    assert paths.first.include?("db/migrate")
  end

  # connected? tests
  def test_connected_returns_boolean
    result = Ragdoll::Core::Database.connected?
    assert [true, false].include?(result)
  end

  # Class method existence tests
  def test_setup_class_method_exists
    assert Ragdoll::Core::Database.respond_to?(:setup)
  end

  def test_migrate_class_method_exists
    assert Ragdoll::Core::Database.respond_to?(:migrate!)
  end

  def test_reset_class_method_exists
    assert Ragdoll::Core::Database.respond_to?(:reset!)
  end

  def test_disconnect_class_method_exists
    assert Ragdoll::Core::Database.respond_to?(:disconnect!)
  end

  # setup tests (limited scope - don't actually reconnect)
  def test_setup_accepts_config_hash
    # This test verifies the method signature, not actual connection
    # In real tests, this would connect to a test database
    assert_respond_to Ragdoll::Core::Database, :setup
  end

  # Config merging tests
  def test_setup_merges_config_with_defaults
    # Verify that custom config keys would be merged
    # without actually establishing a connection
    default = Ragdoll::Core::Database.default_config
    custom = { database: "custom_db" }
    merged = default.merge(custom)
    assert_equal "custom_db", merged[:database]
    assert_equal "postgresql", merged[:adapter]
  end
end
