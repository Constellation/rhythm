# -*- coding: utf-8 -*-
require "singleton"
require "rhythm/color"
require "yaml"

module Rhythm
  DirColor = {
    "NORMAL" => "15"
  }
  class << DirColor
    # standard color definition
    @first = {
      "BACK"     => "#232323", # background
      "DIR"      => "#f0e68c", # directory
      "LINK"     => "#87ceeb", # symbolic link
      "HARDLINK" => "#ade8e6", # regular file with more than one link
      "FIFO"     => "#ffd700", # pipe
      "SOCK"     => "#ffa0a0", # socket
      "DOOR"     => "#ffa0a0", # door
      "BLK"      => "#daa520", # block device driver
      "CHR"      => "#daa520", # character device driver
      "ORPHAN"   => "#cd5c5c", # symlink to nonexistent file, or non-stat'able file
    }

    def get name
      color = self[name]
      color if color
      self["NORMAL"]
    end

    def define dict
      dict.each do |names, color|
        names.each do |name|
          self[name] = Color.get_color(color).to_s
        end
      end
    end

    def define_raw dict
      dict.each do |names, color|
        names.each do |name|
          self[name] = color
        end
      end
    end

    path = File.expand_path(Config['COLOR_DEFINITION'])
    if File.exist?(path)
      File.open(path) do |file|
        @first = YAML.load(file)
      end
    else
      File.open(path, "w") do |file|
        YAML.dump(@first, file)
      end
    end
    @first.each_pair do |key, val|
      DirColor[key] = Color.get_color(val).to_s
    end
  end

  class DirColors < Object
    attr_reader :table
    include Singleton, Color
    def initialize
      # standard color definition
      @first = {
        "BACK"     => "#232323", # background
        "DIR"      => "#f0e68c", # directory
        "LINK"     => "#87ceeb", # symbolic link
        "HARDLINK" => "#ade8e6", # regular file with more than one link
        "FIFO"     => "#ffd700", # pipe
        "SOCK"     => "#ffa0a0", # socket
        "DOOR"     => "#ffa0a0", # door
        "BLK"      => "#daa520", # block device driver
        "CHR"      => "#daa520", # character device driver
        "ORPHAN"   => "#cd5c5c", # symlink to nonexistent file, or non-stat'able file
      }
      @table = {
        "NORMAL" => "15"
      }
      path = File.expand_path(Config['COLOR_DEFINITION'])
      if File.exist?(path)
        File.open(path) do |file|
          @first = YAML.load(file)
        end
      else
        File.open(path, "w") do |file|
          YAML.dump(@first, file)
        end
      end
      @first.each_pair do |key, val|
        @table[key] = get_color(val).to_s
      end
    end
    def method_missing name, *args, &block
      @table.send name, *args, &block
    end
    def get name
      color = @table[name]
      if color == nil
        color = @table["NORMAL"]
      end
      return color
    end
    def define color, *names
      names.each do |name|
        @table[name] = color
      end
    end
  end
end
