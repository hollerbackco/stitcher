require 'bundler'
Bundler.require

Dir[File.dirname(__FILE__) + "/../lib/**/*.rb"].each {|f| require f}
#Dir[File.dirname(__FILE__) + "/lib/**/*.rb"].each {|f| require f}
