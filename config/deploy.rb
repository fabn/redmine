set :application, "redmine"
set :repository, "git://github.com/edavis10/redmine.git"
set :deploy_to, "/var/rails/#{application}"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
set :use_sudo, false
set :deploy_via, :remote_cache

# strongly advised to remember to deploy only stable branches
set :ask_for_tag, true

# rvm setup, see http://beginrescueend.com/integration/capistrano/
$:.unshift(File.expand_path('./lib', ENV['rvm_path'])) # Add RVM's lib directory to the load path.
require "rvm/capistrano" # Load RVM's capistrano plugin.
set :rvm_type, :user # Use local use rvm instead of system one
set :rvm_ruby_string, '1.8.7@redmine'
# multistage setup, see https://boxpanel.bluebox.net/public/the_vault/index.php/Capistrano_Multi_Stage_Instructions
#set :default_stage, "production"
require 'capistrano/ext/multistage'
# capistrano tag library see https://github.com/fabn/capistrano-tags
require 'capistrano-tags'

# Override standard tasks to avoid errors
namespace :deploy do
  task :start do
    logger.important "You should override this in your configuration"
  end
  task :stop do
    logger.important "You should override this in your configuration"
  end
  task :restart, :roles => :app, :except => {:no_release => true} do
    logger.important "You should override this in your configuration"
  end
end

# defaulting rails_env to production
set :rails_env, "production" unless exists? :rails_env
# add other directories to shared folder
set :shared_children, %w(system log pids) + %w(plugins themes config files sqlite)

# Redmine specific tasks
namespace :redmine do

  # Rake helper task.
  def run_remote_rake(rake_cmd, failsafe = false)
    rake = fetch(:rake, "rake")
    command = "cd #{latest_release}; #{rake} RAILS_ENV=#{rails_env} #{rake_cmd.split(',').join(' ')}"
    command << '; true' if failsafe
    run command
  end

  # check if remote file exist
  # inspired by http://stackoverflow.com/questions/1661586/how-can-you-check-to-see-if-a-file-exists-on-the-remote-server-in-capistrano/1662001#1662001
  def remote_file_exists?(full_path)
    'true' == capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
  end

  desc "Initialize configuration using example files provided in the distribution"
  task :copy_config do
    Dir["config/*.yml.example"].each do |file|
      top.upload(File.expand_path(file), "#{shared_path}/config/#{File.basename(file, '.example')}")
    end
  end

  desc "Perform steps required for first installation" # @see http://www.redmine.org/projects/redmine/wiki/RedmineInstall
  task :install do
    # copy shared resources
    symlink.config # configurations
    symlink.files # files folder
    symlink.plugins # copy plugins
    symlink.themes # copy themes
    # guide steps
    session_store # step 4
    migrate # step 5
    load_default_data # step 6
  end

  desc "Perform steps required for upgrades" # see http://www.redmine.org/projects/redmine/wiki/RedmineUpgrade
  task :upgrade do
    symlink.config # configurations (steps 3.2 & 3.3)
    symlink.files # files folder (step 3.4)
    symlink.plugins # copy plugins (step 3.5)
    session_store # regenerate session store (step 3.6)
    symlink.themes # copy themes (step 3.7)
    migrate # migrate your database (step 4)
    cleanup # step 5
  end

  namespace :symlink do
    task :config do
      # copy all shared yml files in config folder
      run "find #{shared_path}/config/ -type f -iname '*.yml' -print0 | xargs -r0 ln -s -t #{release_path}/config/"
    end

    task :files do
      # symlink the files to the shared copy
      run "rm -rf #{latest_release}/files && ln -s #{shared_path}/files #{latest_release}"
    end

    task :plugins do
      # link all installed plugins
      run "find #{shared_path}/plugins/ -mindepth 1 -maxdepth 1 -type d -print0 | xargs -r0 ln -s -t #{latest_release}/vendor/plugins"
    end

    task :themes do
      # link all installed themes
      run "find #{shared_path}/themes/ -mindepth 1 -maxdepth 1 -type d -print0 | xargs -r0 ln -s -t #{latest_release}/public/themes"
    end

    task :sqlite do
      # symlink the sqlite shared folder into the db folder
      run "ln -s #{shared_path}/sqlite #{latest_release}/db"
    end
  end

  desc "Load default Redmine data"
  task :load_default_data do
    run_remote_rake "REDMINE_LANG=#{fetch(:redmine_lang, 'en')},redmine:load_default_data" if fetch(:load_default_data, true)
  end

  desc "Migrate the database"
  task :migrate, :roles => :db, :only => {:primary => true} do
    deploy.migrate
    run_remote_rake "db:migrate:upgrade_plugin_migrations", true
    run_remote_rake "db:migrate_plugins"
  end

  desc "Regenerate session store"
  task :session_store do
    if remote_file_exists? "#{latest_release}/config/initializers/session_store.rb"
      run_remote_rake("config/initializers/session_store.rb")
    else
      run_remote_rake("generate_session_store")
    end
  end

  desc "Cleanup session and cache"
  task :cleanup do
    run_remote_rake "tmp:cache:clear,tmp:sessions:clear"
  end

  # Copy template files that you have locally
  after 'deploy:setup' do
    redmine.copy_config
  end

  # Perform a normal deploy before install
  before 'redmine:install' do
    deploy.default
  end

  # Perform a normal deploy before upgrade
  before 'redmine:upgrade' do
    deploy.default
  end

  # link sqlite folder just before the final symlink is created
  before 'deploy:symlink' do
    redmine.symlink.sqlite
  end
end
