# frozen_string_literal: true

require_relative "../test_helper"
require "rake"

class DbConsoleTaskTest < Minitest::Test
  def setup
    super
    Ragdoll::Core.reset_configuration!
    @rake = Rake::Application.new
    Rake.application = @rake
    load File.expand_path("../../lib/tasks/db.rake", __dir__)
  end

  def teardown
    super
    Rake.application = Rake::Application.new
    Ragdoll::Core.reset_configuration!
  end

  def test_console_passes_configured_database_name_and_user_to_psql
    database = Ragdoll.config.database
    database.host = "db.example"
    database.port = 5433
    database.user = "ragdoll_user"
    database.name = "ragdoll_development"

    command = capture_system_call { @rake["db:console"].invoke }

    assert_equal ["psql", "-h", "db.example", "-p", "5433", "-U", "ragdoll_user", "ragdoll_development"], command
  end

  private

  # The task body runs with the top-level object as self, so stub #system there
  def capture_system_call
    main = TOPLEVEL_BINDING.receiver
    captured = nil
    main.define_singleton_method(:system) { |*args| captured = args }
    capture_io { yield }
    captured
  ensure
    main.singleton_class.send(:remove_method, :system)
  end
end
