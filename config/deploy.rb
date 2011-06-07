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
  desc "Initialize configuration using example files provided in the distribution"
  task :init_config do
    logger.warn "To be implemented"
  end

  desc "Perform steps required for first installation" # @see http://www.redmine.org/projects/redmine/wiki/RedmineInstall
  task :install do

  end

  desc "Perform steps required for upgrades" # see http://www.redmine.org/projects/redmine/wiki/RedmineUpgrade
  task :upgrade do

  end

  namespace :symlink do

    desc "Symlink configuration files"
    task :config do
      # configurations (steps 3.2 & 3.3)
      run "ln -s #{shared_path}/config/database.yml #{release_path}/config/database.yml"
      run "ln -s #{shared_path}/config/email.yml #{release_path}/config/email.yml"
    end

    desc "Symlink files folder"
    task :files do
      # files folder (step 3.4)
      run "rm -rf #{latest_release}/files && ln -s #{shared_path}/files #{latest_release}"
    end

    desc "Symlink all installed plugins which aren't shipped with redmine"
    task :plugins do
      # copy plugins (step 3.5)
      # foreach ln -s
    end

    desc "Symlink all installed themes"
    task :themes do
      # copy themes (step 3.7)
    end
  end

  desc "Cleanup session and cache"
  task :cleanup do
    # step 5
    run "rake tmp:cache:clear"
    run "rake tmp:sessions:clear"
  end

  # Perform install or upgrade steps
  after 'deploy:update_code' do
    if previous_release
      upgrade
    else
      install
    end
  end

  # initialize config files interactively
  after "deploy:setup" do
    init_config
  end
end
