require 'yaml'

module CheckForExtraMigrations
  module MigrationIDs
    MIGRATION_ID_REGEX = /\d{14}/

    def self.from_db
      MigrationRecords.for(DatabaseConfig.adapter)
        .split("\n")
        .select{|line| line.match(MIGRATION_ID_REGEX)}
        .map{|migration_id| migration_id.strip}
    end

    def self.from_migrations_dir
      Dir['db/migrate/*']
        .map do |migration_file_path|
          migration_file_path[MIGRATION_ID_REGEX]
        end
    end

    module MigrationRecords
      def self.for(adapter)
        if adapter == "postgresql"
          `psql #{psql_flags} -c "select version from schema_migrations;"`
        else
          abort "check_for_extra_migrations: Sorry, #{adapter} is not supported yet."
        end
      rescue
        abort "check_for_extra_migrations: Error connecting to PostgreSQL."
      end

      def self.psql_flags
        database = "-d #{DatabaseConfig.database}"
        username = "--username #{DatabaseConfig.username}" if DatabaseConfig.username
        password = "--password #{DatabaseConfig.password}" if DatabaseConfig.password
        port = "--port #{DatabaseConfig.port}" if DatabaseConfig.port
        host = "--hostname #{DatabaseConfig.host}" if DatabaseConfig.host

        "#{database} #{username} #{password} #{port} #{host}"
      end
    end

    module DatabaseConfig
      def self.method_missing(name)
        db_settings["development"][name.to_s]
      end

      private_class_method def self.db_settings
        @@_db_settings ||= YAML.load(File.read('config/database.yml'))
      rescue
        abort "check_for_extra_migrations: You do not appear to be in a Rails project."
      end
    end
  end

  # Set working directory of process to root of current Rails
  # project, if this is run in a subdirectory.
  def self.chdir_to_rails_root
    while Dir.pwd != '/'
      if Dir['*'].any?{ |file| file == "Gemfile" }
        break
      else
        Dir.chdir('..')
      end
    end
  end

  def self.extra_migrations
    ignored_migrations =
      if File.file?('.extra_migrations')
        Marshal.load(File.read('.extra_migrations'))
      else
        []
      end

    @@_extra_migrations ||= MigrationIDs.from_db - MigrationIDs.from_migrations_dir - ignored_migrations
  end

  def self.first_commit_containing(migration_id)
    `git log --all  --reverse --format=\"%H\" -S #{migration_id}`
      .split("\n")
      .first
      .strip
  end

  def self.branches_containing(commit_hash)
    `git branch --contains #{commit_hash}`
      .split("\n")
      .map{ |branch_name| "'#{branch_name[/\S+$/].strip}'" }
      .join(', ')
  end

  def self.migration_info(migration_id)
    commit_hash = first_commit_containing(migration_id)
    puts "* The migration #{migration_id} first appeared in commit #{commit_hash}, which is on these branches: " + branches_containing(commit_hash) + "."
  end

  def self.current_branch
    `git rev-parse --abbrev-ref HEAD`.chomp
  end


  def self.check_for_extra_migrations
    if !extra_migrations.empty?
      puts "Migrations have been run that are not present in this branch ('#{current_branch}'): #{extra_migrations.join(', ')}."
      extra_migrations.each do |migration_id|
        migration_info(migration_id)
      end
    end
  end

  def self.calibrate
    File.open('.extra_migrations', 'w') do |file|
      migrations_to_ignore = MigrationIDs.from_db - MigrationIDs.from_migrations_dir
      file.write(Marshal.dump(migrations_to_ignore))
      puts "Wrote to #{file.path}."
    end
  end

  def self.execute(command)
    chdir_to_rails_root

    if command == 'calibrate'
      calibrate
    else
      check_for_extra_migrations
    end
  end
end
