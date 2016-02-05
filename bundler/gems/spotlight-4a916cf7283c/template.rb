DEFAULT_BLACKLIGHT_OPTIONS = '--devise --jettywrapper'
DEFAULT_SPOTLIGHT_OPTIONS = '-f --openseadragon --mailer_default_url_host=localhost:3000'
blacklight_options = ENV.fetch('BLACKLIGHT_INSTALL_OPTIONS', DEFAULT_BLACKLIGHT_OPTIONS)
spotlight_options = ENV.fetch('SPOTLIGHT_INSTALL_OPTIONS', DEFAULT_SPOTLIGHT_OPTIONS)

# Add gem dependencies to the application
gem 'blacklight', '~> 5.16'
gem 'blacklight-spotlight', ENV['SPOTLIGHT_GEM'] ? { path: ENV['SPOTLIGHT_GEM'] } : { github: 'sul-dlss/spotlight' }

Bundler.with_clean_env do
  run 'bundle install'
end

# run the blacklight install generator
generate 'blacklight:install', blacklight_options

# run the spotlight installer
generate 'spotlight:install', spotlight_options
rake 'spotlight:install:migrations'

# create an initial administrator (if we are running interactively..)
if !options['quiet'] && yes?('Would you like to create an initial administrator?')
  rake 'db:migrate' # we only need to run the migrations if we are creating an admin user
  rake 'spotlight:initialize'
end

# and configure jetty with a useful configuration
rake 'jetty:configure_solr' if blacklight_options =~ /jettywrapper/