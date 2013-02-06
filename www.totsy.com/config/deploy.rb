require 'socket' # for haproxy communication

set :stages,        %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :application, "Totsy-Magento"
set :repository,  "git@github.com:Totsy/#{application}.git"

set :scm,          :git
set :scm_verbose,  true
set :scm_username, "totsy-release"
set :deploy_via,   :remote_cache

set :user,      "release"
set :group,     "nginx"
set :deploy_to, "/var/www/www.totsy.com"

ssh_options[:keys] = %w(~/.ssh/id_rsa)
ssh_options[:port] = 22

set :shared_children, shared_children + [ 'var' ]

set :use_sudo, false
set :normalize_asset_timestamps, false

namespace(:app) do
    desc "Perform the final deployment steps of setting up the web application"
    task :configure do
        run "cd #{release_path} && tar xf /usr/share/magento/magento-enterprise-1.11.1.tar.bz2 --strip-components=1 --skip-old-files"
	run "ln -s #{shared_path}/var #{release_path}"
	run "ln -s /srv/share/media #{release_path}"
	run "ln -s /srv/share/akamai #{release_path}"
	run "ln -sf /etc/magento/local.xml #{release_path}/app/etc/"
    end

    desc "Prepare the deployment directory"
    task :setup do
        run "chgrp -R nginx #{shared_path}/*"
        run "chmod -R 775 #{shared_path}/*"
        run "ln -s /srv/share/var/tmp #{shared_path}/var/tmp"
    end
end

namespace :deploy do
    desc "Stop web application services"
    task :stop do
        run "sudo /etc/init.d/php-fpm stop"
        run "sudo /etc/init.d/nginx stop"
    end

    desc "Start web application services"
    task :start do
        run "sudo /etc/init.d/php-fpm start"
        run "sudo /etc/init.d/nginx start"
    end

    desc "Restart web application services"
    task :restart do
        run "sudo /etc/init.d/php-fpm restart"
        run "sudo /etc/init.d/nginx restart"
    end

    desc "Configure the correct robots.txt file for the environment"
    task :robot do
        run "cp -f #{release_path}/robots-prod.txt #{release_path}/robots.txt"
    end

    namespace :web do
        desc "Put web servers into maintenance mode"
        task :disable do
            run "touch #{deploy_to}/current/maintenance.flag"
        end

        desc "Bring web servers out of maintenance mode"
        task :enable do
            run "rm #{deploy_to}/current/maintenance.flag"
        end
    end
end

namespace :loadbalancer do
    desc "Disable each of the target deployment servers in haproxy"
    task :disable do
        servers = find_servers
        servers.each do |hostname|
            [ 'main_http_backend', 'main_https_backend' ].each do |backend|
                begin
                    socket = UNIXSocket.new("/var/run/haproxy.sock")
                    socket.puts("disable server #{backend}/#{hostname}")
                    socket.close
                rescue => e
                    logger.important e.message
                end
            end
        end

        sleep 3
    end

    desc "Enable each of the target deployment servers in haproxy"
    task :enable do
        servers = find_servers
        servers.each do |hostname|
            [ 'main_http_backend', 'main_https_backend' ].each do |backend|
                begin
                    socket = UNIXSocket.new("/var/run/haproxy.sock")
                    socket.puts("enable server #{backend}/#{hostname}")
                    socket.close
                rescue => e
                    logger.important e.message
                end
            end
        end

        sleep 3
    end
end

after "deploy:cleanup" do
    repository_cache = File.join(shared_path, "cached-copy")
    run "cd #{repository_cache} && git remote prune origin"
end

after "deploy:setup",		"app:setup"
after "deploy:update_code",     "app:configure"
after "deploy:finalize_update", "deploy:robot"

