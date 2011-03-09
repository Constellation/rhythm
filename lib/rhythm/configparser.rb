# -*- coding: utf-8 -*-
class ConfigParser < Object
  @@sec = /\[([^\]]+)\]/
  @@val = /([^:=\s]*)[^:=]*\s*([:=])\s*(.*)$/
  @@comment = ['"', '#']
  class FileNotFound < Exception
  end
  class SectionNotDefined < Exception
  end
  class ParsingError < Exception
  end

  attr_reader :hash
  def initialize
    @body = nil
    @file_found_flag = false
    @hash = {}
  end
  def read filename
    raise FileNotFound unless File.exist filename
    current = nil
    File.open(filename) do |file|
      line = file.readline.strip!
      # comment or blank line
      if line === '' || @@comment.include?(line[0].chr)
        next
      # section header
      elsif @@sec =~ line
        current = @hash[$1] = {}
      elsif current === nil
        raise SectionNotDefined
      elsif @@val =~ line
        current[$1] = $3
      else
        raise ParsingError
      end
    end
    @file_found_flag = true
  end
end

