require 'bundler'
Bundler.require

CONFIG = YAML.load_file("./config/aws.yml")

AWS.config(access_key_id: CONFIG["AWS_ACCESS_KEY_ID"],
           secret_access_key: CONFIG["AWS_SECRET_ACCESS_KEY"])

require File.dirname(__FILE__) + "/../lib/stitcher_service.rb"
