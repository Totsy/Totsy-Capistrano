set :stages, %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :application, "Totsy-API"
set :repository,  "git@github.com:Totsy/#{application}.git"

set :scm, :git
set :scm_verbose, true
set :scm_username, "totsy-release"
set :deploy_via, :remote_cache

set :user, "release"
set :group, "nginx"
set :deploy_to, "/var/www/api.totsy.com"

set :shared_children, shared_children + [ 'vendor' ]

ssh_options[:keys] = %w(~/.ssh/id_rsa)
ssh_options[:port] = 22

set :use_sudo, false
set :normalize_asset_timestamps, false

namespace :app do
    desc "Perform the final deployment steps of setting up the web application"
    task :configure do
        run "mkdir #{release_path}/etc && ln -s /etc/totsy-api/logger.yaml #{release_path}/etc/logger.yaml"
        run "ln -s #{shared_path}/vendor #{release_path}/vendor"
        run "cd #{release_path} && composer update"
        run "cd #{release_path}/doc/wadl && xsltproc totsy_wadl_doc-2006-10.xsl totsy.wadl > index.html"
    end

    desc "Prepare the deployment directory"
    task :setup do
        run "chgrp -R nginx #{shared_path}/log"
        run "chmod -R 775 #{shared_path}/log"
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
end

namespace :loadbalancer do
    desc "Disable each of the target deployment servers in haproxy"
    task :disable do
        servers = find_servers_for_task(current_task)
        servers.each do |host|
            [ 'main_http', 'main_https' ].each do |backend|
                socket = UNIXSocket.new("/var/run/haproxy.sock")
                socket.puts("disable server #{backend}/#{host}")
            end
        end
    end

    desc "Enable each of the target deployment servers in haproxy"
    task :enable do
        servers = find_servers_for_task(current_task)
        servers.each do |host|
            [ 'main_http', 'main_https' ].each do |backend|
                socket = UNIXSocket.new("/var/run/haproxy.sock")
                socket.puts("enable server #{backend}/#{host}")
            end
        end
    end
end

after "deploy:update_code", "app:configure"
after "deploy:setup",       "app:setup"

