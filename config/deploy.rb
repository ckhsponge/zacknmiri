require 'mt-capistrano'
 
set :site,         "1727"
set :application,  "zacknmiri"
set :webpath,      "zacknmiri.com"
set :domain,       "spongecorp.com"
set :user,         "serveradmin%spongecorp.com"
set :password,     "wKnAgM68"
 
#ssh_options[:username] = 'serveradmin%primarydomain.com'
 
set :scm, :git
#set :scm_command, "/home/1727/users/.home/usr/bin/git"
set :repository, "git://github.com/ckhsponge/zacknmiri.git"
set :deploy_to,  "/home/#{site}/containers/rails/#{application}"
set :current_deploy_dir, "#{deploy_to}/current"
set :tmp_dir, "#{deploy_to}/tmp"
 
set :checkout, "export"
 
role :web, "#{domain}"
role :app, "#{domain}"
role :db,  "#{domain}", :primary => true
 
task :after_update_code, :roles => :app do
  run "cp #{deploy_to}/shared/config/database.yml #{release_path}/config/database.yml"
  run "cp #{deploy_to}/shared/config/facebooker.yml #{release_path}/config/facebooker.yml"
  #put(File.read('private/account.yml'), "#{release_path}/config/account.yml", :mode => 0444)
  #put(File.read('config/database.yml'), "#{release_path}/config/database.yml", :mode => 0444)
  #tar_source
end

#namespace :deploy do
#  task :migrate do
#    run "cd #{current_deploy_dir} && PATH=/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/games:/home/1727/data/rubygems/bin:/home/1727/data/rubygems/gems/bin GEM_HOME=/home/1727/data/rubygems/gems RUBY_LIB=/home/1727/data/rubygems/local/lib/site_ruby/1.8:/home/1727/data/rubygems/lib /home/#{site}/data/rubygems/gems/bin/rake db:migrate production"
#  end
#end

namespace :mt do
  task :init_dir do
    run "mkdir -p #{deploy_to}"
    run "mkdir -p #{deploy_to}/shared"
    run "mkdir -p #{deploy_to}/shared/log"
    run "mkdir -p #{deploy_to}/releases"
  end
end
 
namespace :deploy do
task :restart, :roles => :app do
  #run "mtr restart #{application} -u #{user} -p #{password}"
  #run "mtr generate_htaccess #{application} -u #{user} -p #{password}"
  run "mtr restart #{application} -u #{user} -p #{password}"
  run "mtr generate_htaccess #{application} -u #{user} -p #{password}"
  #migrate
end
end
