require_relative 'generator.rb'

g = Moonset::Generator.new config_file: "config.rb"
g.run
