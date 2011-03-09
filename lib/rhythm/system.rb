# -*- coding: utf-8 -*-

module Rhythm
  module Sys
    @@env_path = ENV["PATH"].split(':')
    def which cmd
      result = nil
      res = @@env_path.detect do |path|
        File.exist?(result = File.join(path, cmd))
      end
      return res ? result : nil
    end
    module_function :which

    def create_temp_directory
      id = 0
      path = nil
      loop do
        path = File.join(Config['TEMP'], "RHYTHMTEMP#{id}")
        break unless File.exist?(path)
        id+=1
      end
      Dir.mkdir(path)
      return path
    end
    module_function :create_temp_directory

    def exist_library? lib
      result = nil
      res = $:.detect do |path|
        File.exist?(result = File.join(path, lib))
      end
      return res ? result : nil
    end
    module_function :exist_library?
  end
end
