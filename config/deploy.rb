set :application, "redmine"
set :repository, "git://github.com/edavis10/redmine.git"
set :deploy_to, "/var/rails/#{application}"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
set :use_sudo, false
set :deploy_via, :remote_cache

# rvm setup, see http://beginrescueend.com/integration/capistrano/
$:.unshift(File.expand_path('./lib', ENV['rvm_path'])) # Add RVM's lib directory to the load path.
require "rvm/capistrano" # Load RVM's capistrano plugin.
set :rvm_type, :user # Use local use rvm instead of system one
set :rvm_ruby_string, '1.8.7-p302@redmine'
# multistage setup, see https://boxpanel.bluebox.net/public/the_vault/index.php/Capistrano_Multi_Stage_Instructions
set :default_stage, "production"
set :stages, %w(production staging)
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

# Redmine specific tasks
namespace :redmine do

  # Rake helper task.
  def run_remote_rake(rake_cmd)
    rake = fetch(:rake, "rake")
    rails_env = fetch(:rails_env, "production")
    run "cd #{latest_release}; #{rake} RAILS_ENV=#{rails_env} #{rake_cmd.split(',').join(' ')}"
  end

  # check if remote file exist
  # inspired by http://stackoverflow.com/questions/1661586/how-can-you-check-to-see-if-a-file-exists-on-the-remote-server-in-capistrano/1662001#1662001
  def remote_file_exists?(full_path)
    'true' == capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
  end

  desc "Initialize configuration using example files provided in the distribution"
  task :init_config do
    logger.important "To be implemented"
  end

  desc "Perform steps required for first installation" # @see http://www.redmine.org/projects/redmine/wiki/RedmineInstall
  task :install do

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
      run "ln -s #{shared_path}/config/*.yml #{release_path}/config/"
    end

    task :files do
      # symlink the files to the shared copy
      run "rm -rf #{latest_release}/files && ln -s #{shared_path}/files #{latest_release}"
    end

    task :plugins do
      # link all installed plugins
      run "ln -s #{shared_path}/plugins/* #{latest_release}/vendor/plugins"
    end

    task :themes do
      # link all installed themes
      run "ln -s #{shared_path}/public/themes/* #{latest_release}/public/themes"
    end
  end

  desc "Migrate the database"
  task :migrate, :roles => :db, :only => {:primary => true} do
    deploy.migrate
    run_remote_rake "db:migrate:upgrade_plugin_migrations"
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

  # Perform install or upgrade steps
  after 'deploy:update_code' do
    upgrade
  end

  # initialize config files interactively
  after "deploy:setup" do
    init_config
  end
end
