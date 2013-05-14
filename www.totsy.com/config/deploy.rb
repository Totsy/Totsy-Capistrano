require 'socket' # for haproxy communication
require 'varnishclient' # for varnish communication
require 'hipchat/capistrano' # for hipchat integration

set :stages,        %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :application, "Totsy-Magento"
set :repository,  "git@github.com:Totsy/#{application}.git"
#set :repository,  "https://totsy-release:thematr1x@github.com/Totsy/#{application}.git"

set :scm,          :git
set :scm_verbose,  true
set :scm_username, "totsy-release"
set :deploy_via,   :remote_cache
#set :deploy_via,   :checkout

set :user,      "release"
set :group,     "nginx"
set :deploy_to, "/var/www/www.totsy.com"

ssh_options[:keys] = %w(~/.ssh/id_rsa)
ssh_options[:port] = 22

set :shared_children, shared_children + [ 'var' ]

set :use_sudo, false
set :normalize_asset_timestamps, false

# hipchat integration options
set :hipchat_token, "5b6ea132c1fa2d487ac57c0f8b4e9f"
set :hipchat_room_name, "Tech Stream"
set :hipchat_announce, false
set :hipchat_human, "A release master"

namespace(:app) do
    desc "Perform the final deployment steps of setting up the web application"
    task :configure do
        run "cd #{release_path} && tar xf /usr/share/magento/magento-enterprise-1.11.1.tar.bz2 --strip-components=1 --skip-old-files"
	run "ln -s #{shared_path}/var #{release_path}"
	run "ln -s /srv/share/media #{release_path}"
	run "ln -s /srv/share/akamai #{release_path}"
	run "ln -sf /etc/magento/local.xml #{release_path}/app/etc/"
	run "ln -sf /etc/magento/litle_SDK_config.ini #{release_path}/app/code/community/Litle/LitleSDK/"
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

        client = VarnishClient.new
        client.connect 'infra2.totsy.net', 6082

        servers.each do |hostname|
            hostname = hostname.to_s
            begin
                # disable host in varnish
                hostprefix = hostname[0, hostname.length - 4]
                client.command "backend.set_health #{hostprefix} sick"

                # disable host in haproxy
                socket = UNIXSocket.new("/var/run/haproxy.sock")
                socket.puts("disable server main_https_backend/#{hostname}")
                socket.close
            rescue => e
                logger.important "Error while disabling server #{hostname}: #{e.message}"
            end
        end

        client.disconnect
    end

    desc "Enable each of the target deployment servers in haproxy"
    task :enable do
        servers = find_servers

        client = VarnishClient.new
        client.connect 'infra2.totsy.net', 6082

        servers.each do |hostname|
            hostname = hostname.to_s
            begin
                # enable host in varnish
                hostprefix = hostname[0, hostname.length - 4]
                client.command "backend.set_health #{hostprefix} healthy"

                # disable host in haproxy
                socket = UNIXSocket.new("/var/run/haproxy.sock")
                socket.puts("enable server main_https_backend/#{hostname}")
                socket.close
            rescue => e
                logger.important "Error while disabling server #{hostname}: #{e.message}"
            end
        end

        client.disconnect
    end
end

after "deploy:cleanup" do
    repository_cache = File.join(shared_path, "cached-copy")
    run "cd #{repository_cache} && git remote prune origin"
end

after "deploy:setup",		"app:setup"
after "deploy:update_code",     "app:configure"
after "deploy:finalize_update", "deploy:robot"

