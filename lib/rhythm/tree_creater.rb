# -*- coding: utf-8 -*-
#
# pathes to tree
#
module Rhythm
  module TreeCreater
    def create pathes
      root = TreeEntry.new('/')
      pathes.each do |path|
        current = root
        path = File.expand_path(path, '/')
        basename, dirs = split_names(path)
        dirs.each do |dir_name|
          unless current.has?(dir_name)
            current = current[dir_name] = TreeEntry.new(dir_name, current)
          else
            current = current[dir_name]
          end
        end
        current[basename] = TreeEntry.new(path)
      end
      return root
    end
    module_function :create

    # chop_basename(path) -> [pre-basename, basename] or nil
    def chop_basename(path)
      base = File.basename(path)
      if /\A#{SEPARATOR_PAT}?\z/o =~ base
        return nil
      else
        return path[0, path.rindex(base)], base
      end
    end

    # split_names(path) -> prefix, [name, ...]
    def split_names(path)
      names = []
      while r = chop_basename(path)
        path, basename = r
        names.unshift basename
      end
      return path, names
    end

    class TreeEntry
      attr_reader :path
      attr_accessor :table
      def initialize path, parent=nil
        @parent = parent
        @path = path
        @table = {}
      end

      def children
        @table.values
      end

      def []= key, val
        @table[key] = val
      end

      def [] key
        @table[key]
      end

      def has? key
        @table.key?(key)
      end
    end
  end
end


