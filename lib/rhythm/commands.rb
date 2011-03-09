# -*- coding: utf-8 -*-
require 'fileutils'
require 'singleton'

module Rhythm

  # super class of all commands
  class BasicCommand < Object
    include Rhythm::Utils, Singleton
    attr_reader :name
    def initialize name
      @name = name
      Commands::HASH[name] = self
    end
    def self.execute
      self.instance.execute
    end
  end

  # FileUtils をinclude した SystemCommand
  class SystemCommand < BasicCommand
    include FileUtils::Verbose
    def initialize name
      @fileutils_output = notify
      super(name)
    end
  end

  # normal command class
  class Command < BasicCommand
    def initialize name
      super(name)
    end
  end

end
