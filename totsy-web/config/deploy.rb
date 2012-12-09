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

after "deploy:update_code", "customs:post_config"
after "deploy:symlink", "customs:start_services"

namespace(:customs) do
    desc "Post install configurations"
    task :post_config do
        run "cd #{release_path} && tar xkf /usr/share/magento/magento-enterprise-1.11.1.tar.bz2 --strip-components=1"
	run "mkdir #{release_path}/var && chgrp nginx #{release_path}/var && chmod g+w #{release_path}/var"
	run "ln -s /srv/cache/var/tmp #{release_path}/var/tmp"
	run "ln -s /srv/cache/media #{release_path}"
	run "ln -s /srv/cache/akamai #{release_path}"
	run "ln -sf /etc/magento/local.xml #{release_path}/app/etc/"
	run "ln -sf /etc/magento/enterprise.xml #{release_path}/app/etc/"
        run "sudo /etc/init.d/php-fpm stop"
        run "sudo /etc/init.d/nginx stop"
    end
    desc "start services"
    task :start_services do
        run "sudo /etc/init.d/php-fpm start"
        run "sudo /etc/init.d/nginx start"
    end
end

