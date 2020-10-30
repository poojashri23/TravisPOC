#!/usr/bin/env ruby

if defined? Encoding
  Encoding.default_external = Encoding::UTF_8
end

require 'rubygems'
require 'fileutils'
require 'xcodeproj'

name = ARGV[0]

if name == "?"
  puts "Usage: Updates Target verion in shared config file"
  exit
end

if ARGV.length != 4 then
    puts ARGV
  puts "Usage: Updates Target verion in shared config file"
end

updated_target_version = ARGV[1]

puts "\n"

# Update the shared configuration file.

Dir.chdir("Configs/ClientSpecific/")

Dir.glob("#{name}-Shared.xcconfig") {|filename|
  data = File.open(filename, "r")

  new_contents = data.map do |line|
    (line.include? 'TARGET_VERSION_NUMBER') ? "TARGET_VERSION_NUMBER = #{updated_target_version}\n" : line
  end 
  
  File.open(filename, "w") {|file| file.puts new_contents }
  
  puts "Successfully updated shared xcconfig file.".green
}

puts "\n"


