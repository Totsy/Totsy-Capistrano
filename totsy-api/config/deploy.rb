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

after "deploy:update_code", "customs:post_config"

namespace(:customs) do
    desc "Post install configurations"
    task :post_config do
        run "mkdir #{release_path}/etc && ln -s /etc/totsy-api/logger.yaml #{release_path}/etc/logger.yaml"
        run "ln -s #{shared_path}/vendor #{release_path}/vendor"
        run "cd #{release_path} && composer update"
        run "cd #{release_path}/doc/wadl && xsltproc totsy_wadl_doc-2006-10.xsl totsy.wadl > index.html"
        run "sudo /etc/init.d/php-fpm stop"
        run "sudo /etc/init.d/nginx stop"
    end
    desc "start services"
    task :start_services do
        run "sudo /etc/init.d/php-fpm start"
        run "sudo /etc/init.d/nginx start"
    end
end
