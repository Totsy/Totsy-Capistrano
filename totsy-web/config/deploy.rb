require 'socket' # for haproxy communication

set :stages, %w(production staging backup)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :application, "Totsy-Magento"
set :repository,  "git@github.com:Totsy/#{application}.git"

set :scm, :git
set :scm_verbose, true
set :scm_username, "totsy-release"
set :deploy_via, :remote_cache

set :user, "release"
set :group, "nginx"
set :deploy_to, "/var/www/www.totsy.com"

ssh_options[:keys] = %w(~/.ssh/id_rsa)
ssh_options[:port] = 22

set :use_sudo, false
set :normalize_asset_timestamps, false

namespace(:app) do
    desc "Perform the final deployment steps of setting up the web application"
    task :setup do
        run "cd #{release_path} && tar xkf /usr/share/magento/magento-enterprise-1.11.1.tar.bz2 --strip-components=1"
	run "mkdir #{release_path}/var && chgrp nginx #{release_path}/var && chmod g+w #{release_path}/var"
	run "ln -s /srv/cache/var/tmp #{release_path}/var/tmp"
	run "ln -s /srv/cache/media #{release_path}"
	run "ln -s /srv/cache/akamai #{release_path}"
	run "ln -sf /etc/magento/local.xml #{release_path}/app/etc/"
	run "ln -sf /etc/magento/enterprise.xml #{release_path}/app/etc/"
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
end

namespace :loadbalancer do
    desc "Disable each of the target deployment servers in haproxy"
    task :withdraw do
        servers = find_servers_for_task(current_task)
        servers.each do |host|
            [ 'main_http', 'main_https' ].each do |backend|
                socket = UNIXSocket.new("/var/run/haproxy.sock")
                socket.puts("disable server #{backend}/#{host}")
            end
        end
    end

    desc "Enable each of the target deployment servers in haproxy"
    task :restore do
    end
end

after "deploy:update_code", "app:setup"

