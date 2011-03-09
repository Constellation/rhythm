#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Rhythm Extension Packager
# inspired form Google Chrome Extension
#
require "json"
require "zlib"
require "fileutils"

module Rhythm
  module Package
    MANIFEST = 'manifest.json'
    MAGIC_NUMBER = [?R, ?H, ?Y, ?T, ?H, ?M].pack('C*')
    MAGIC_SIZE = MAGIC_NUMBER.size
    HEADER_SIZE = 28
    MAIN_HEADER_SIZE = 16
    VERSION = 1

    class InputEntry < Object
      attr_reader :path, :mode, :mtime
      def initialize path, root
        @real = path
        @path = path.last(path.size-root.size-1)
        stat = File.stat(@real)
        @dir = stat.directory?
        @mtime = stat.mtime.to_i
        @mode = stat.mode
        @header = [@mode, @mtime, HEADER_SIZE, @path.size]
      end
      def directory?
        @dir
      end
      def read
        if @dir
          @header << 0
          return @header.pack('L!qL!L!Q') << @path
        else
          data = File.open(@real, 'rb') do |f|
            Zlib::Deflate.deflate(f.read)
          end
          @header << data.size
          return @header.pack('L!qL!L!Q') << @path << data
        end
      end
    end

    class Packager < Object
      @@ignore_dirs = ['.git', '.svn', 'CVS', '.hg']
      @@ignore_files = []
      def initialize indir
        @dir = File.expand_path(indir)
        @pathes = []
        @manifest_file = File.join(@dir, MANIFEST)
        @manifest = nil
      end
      def pack outfile, verbose=true
        begin
          outfile_set outfile
          walk @dir, verbose
          validate
          write
          puts "done" if verbose
        rescue => e
          perr e
        end
        #pp @pathes
      end
      def outfile_set outfile
        @out = File.expand_path(outfile)
      end
      def validate
        unless @pathes.include?(@manifest_file)
          raise "manifest file is not found!"
        end
      end
      def write
        File.open(@manifest_file, 'rb') do |file|
          @manifest = JSON.parse(file.read)
        end
        json_data = JSON.generate(@manifest)
        header = [0, VERSION, MAIN_HEADER_SIZE, json_data.size].pack('L4')
        File.open(@out, 'wb') do |file|
          # magic number
          file.write(MAGIC_NUMBER)
          file.write(header)
          file.write(json_data)
          @pathes.each do |path|
            file.write(InputEntry.new(path, @dir).read)
          end
        end
      end
      def walk p, verbose=false
        children(p).each do |path|
          if File.directory? path
            unless @@ignore_dirs.include?(File.basename(path))
              puts "packaging #{path}" if verbose
              @pathes << path
              walk(path)
            end
          elsif File.file? path
            unless @@ignore_files.include?(File.basename(path))
              puts "packaging #{path}" if verbose
              @pathes << path
            end
          end
        end
      end
      def children path
        result = []
        Dir.foreach(path) do |e|
          next if e == '.' || e == '..'
          result << File.join(path, e)
        end
        result
      end
    end

    class UnPackager < Object
      def initialize path
        @in = File.expand_path(path)
        @manifest = nil
      end
      def unpack outdir, verbose=true
        begin
          outdir_set outdir
          extract verbose
          puts "done" if verbose
        rescue => e
          STDERR << e.to_s
        end
      end
      def outdir_set outdir
        @dir = File.expand_path(outdir)
        unless File.exist? @dir
          FileUtils.mkdir_p @dir
        else
          unless File.directory? @dir
            raise "#{@dir} is not directory"
          end
        end
      end
      def extract verbose
        File.open(@in, 'rb') do |fd|
          validate(fd.read(MAGIC_SIZE))
          num, version, header_size, datasize = fd.read(16).unpack('L4')
          @manifest = JSON.parse(fd.read(datasize))
          walk fd, verbose
        #  header = fd.read(HEADER_SIZE).unpack('L!qL!L!Q')
        end
      end
      def validate magic
        unless magic == MAGIC_NUMBER
          raise "#{@in} is not rhythm extension"
        end
      end
      def walk fd, verbose
        header = nil
        loop do
          header = fd.read(HEADER_SIZE)
          if header
            writer header, fd, verbose
          else
            break
          end
        end
      end
      def writer header, fd, verbose
        mode, mtime, header_size, pathsize, datasize = header.unpack('L!qL!L!Q')
        path = File.expand_path(fd.read(pathsize), @dir)
        FileUtils.mkdir_p(File.dirname(path))
        directory = (mode & 0170000 ) == 00040000
        puts "unpackaging #{path}" if verbose
        if directory
          FileUtils.mkdir_p path
        else
          File.open(path, 'wb') do |file|
            file.puts(Zlib::Inflate.inflate(fd.read(datasize)))
          end
          File.utime(mtime, mtime, path)
        end
      end
      def show_manifest
        begin
          File.open(@in, 'rb') do |fd|
            validate(fd.read(MAGIC_SIZE))
            num, version, header_size, datasize = fd.read(16).unpack('L4')
            @manifest = JSON.parse(fd.read(datasize))
          end
          STDOUT << JSON.pretty_generate(@manifest)
        rescue => e
          STDERR << e.to_s
        end
      end
    end

  end
end

