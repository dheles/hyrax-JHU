require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sufia
  class Application < Rails::Application
config.active_job.queue_adapter = :inline

      # The compile method (default in tinymce-rails 4.5.2) doesn't work when also
      # using tinymce-rails-imageupload, so revert to the :copy method
      # https://github.com/spohlenz/tinymce-rails/issues/183
      config.tinymce.install = :copy
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
  end
end
