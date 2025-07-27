# frozen_string_literal: true

require "annotate"
require "annotate/annotate_models"

# Define environment task for gem context
task :environment do
  # Load the gem's environment
  require_relative "../ragdoll-core"

  # Set up database connection
  begin
    # Load all models to ensure they're available
    Dir[File.join(__dir__, "../ragdoll/core/models/*.rb")].each { |file| require file }

    # Set up database connection with default config
    Ragdoll::Core::Database.setup({
                                    adapter: "postgresql",
                                    database: "ragdoll_development",
                                    username: "ragdoll",
                                    password: ENV["RAGDOLL_DATABASE_PASSWORD"] || ENV["DATABASE_PASSWORD"],
                                    host: "localhost",
                                    port: 5432,
                                    auto_migrate: false # Don't auto-migrate during annotation
                                  })

    puts "✅ Connected to database: ragdoll_development"
  rescue StandardError => e
    puts "❌ Database connection failed: #{e.message}"
    puts "   Annotations will be based on model definitions only"
  end
end

namespace :annotate do
  task :models do
    AnnotateModels.do_annotations({
                                    "models" => "true",
                                    "position_in_class" => "before",
                                    "show_foreign_keys" => "true",
                                    "show_indexes" => "true",
                                    "model_dir" => "lib/ragdoll/core/models",
                                    "exclude_tests" => "true",
                                    "exclude_fixtures" => "true",
                                    "exclude_factories" => "true",
                                    "exclude_serializers" => "true",
                                    "exclude_scaffolds" => "true",
                                    "exclude_controllers" => "true",
                                    "exclude_helpers" => "true"
                                  })
  end
end

task :set_annotation_options do
  # You can override any of these by setting an environment variable of the
  # same name.
  Annotate.set_defaults(
    "active_admin" => "false",
    "additional_file_patterns" => [],
    "routes" => "false",
    "models" => "true",
    "position_in_routes" => "before",
    "position_in_class" => "before",
    "position_in_test" => "before",
    "position_in_fixture" => "before",
    "position_in_factory" => "before",
    "position_in_serializer" => "before",
    "show_foreign_keys" => "true",
    "show_complete_foreign_keys" => "false",
    "show_indexes" => "true",
    "simple_indexes" => "false",
    "model_dir" => "lib/ragdoll/core/models",
    "root_dir" => "",
    "include_version" => "false",
    "require" => "",
    "exclude_tests" => "false",
    "exclude_fixtures" => "false",
    "exclude_factories" => "false",
    "exclude_serializers" => "false",
    "exclude_scaffolds" => "false",
    "exclude_controllers" => "true",
    "exclude_helpers" => "true",
    "exclude_sti_subclasses" => "false",
    "ignore_model_sub_dir" => "false",
    "ignore_columns" => nil,
    "ignore_routes" => nil,
    "ignore_unknown_options" => "false",
    "hide_limit_column_types" => "integer,bigint,boolean",
    "hide_default_column_types" => "json,jsonb,hstore",
    "skip_on_db_migrate" => "false",
    "format_bare" => "true",
    "format_rdoc" => "false",
    "format_yard" => "false",
    "format_markdown" => "false",
    "sort" => "false",
    "force" => "false",
    "frozen" => "false",
    "classified_sort" => "true",
    "trace" => "false",
    "wrapper_open" => nil,
    "wrapper_close" => nil,
    "with_comment" => "true"
  )
end

# Load only essential model annotation tasks
desc "Add schema information (as comments) to model files"
task annotate_models: :environment do
  puts "Running annotate for ragdoll-core models..."

  # Use the CLI approach since the programmatic API doesn't respect model_dir properly
  success = system("MODEL_DIR=lib/ragdoll/core/models bundle exec annotate --models --position-in-class=before --show-foreign-keys --show-indexes")

  if success
    puts "✅ Model annotations updated successfully!"
  else
    puts "⚠️  Annotate completed with warnings (database connection issues)"
  end
end

desc "Remove schema information from model files"
task :remove_annotation do
  AnnotateModels.remove_annotations({
                                      "models" => "true",
                                      "model_dir" => "lib/ragdoll/core/models"
                                    })
end
