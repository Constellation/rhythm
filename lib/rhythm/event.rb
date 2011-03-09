# -*- coding: utf-8 -*-
# event interface
# いくつかの設定の動的変更,
# 及びstatusの変更などのeventの独自発行
#

module Rhythm
  class Ev < Object
    def initialize
      @read, @write = IO.pipe
    end

    def send str=""
      @write.write str
    end

    def recv
      @read.readpartial 4096
    end

    def self.condver
      return self.new
    end

    class Handle < Object
      def initialize hash
        @fh = hash[:fh]
        @thread = Thread.new do
          begin
            while !(data = @fh.read).empty?
              hash.key? :read && hash[:read].call(data)
            end
            hash.key? :eof && hash[:eof].call
          rescue
            hash.key? :error && hash[:error].call
          ensure
            destroy
          end
        end
      end

      def destroy
        @fh.close
        @thread.kill
      end
    end

    require 'net/http'
    require 'uri'
    class HTTP < Object
      @@methods = [:get, :post, :head, :delete, :put]
      def initialize hash
        @hash = hash
        @header = hash[:header]
        @data = hash[:data]
        @method = @@methods.detect do |sym|
          hash.key? sym
        end
        @method = hash[:method] unless @method
        @timeout = hash[:timeout]
        @url = URI.parse hash[@method]
        @thread = Thread.new do
          Net::HTTP::start @url.host, @url.port do |http|
            if defined? @method
              req = __send__ @method, http
            else
              req = http.__send__ @method, @url.path, @header
            end
            hash[:load].call(req)
          end
        end
      end

      def destory

      end
      private
      def get http
        return http.get @url.path, @header
      end
      def post http
        return http.post @url.path, @data, @header
      end
      def head http
        return http.head @url.path, @header
      end
      def delete http
        return http.delete @url.path, @header
      end
      def put http
        return http.put @url.path, @header
      end
    end
  end
end

#module Rhythm
#  cv = Ev::condver
#  Ev::Handle.new(
#    :fh => File.open(File.expand_path('~/test.rb')),
#    :read => lambda do |data|
#      cv.send data
#    end,
#    :eof => lambda do
#      cv.send "EOF!!!"
#    end,
#    :error => lambda do
#      cv.send "ERROR!!!!"
#    end
#  )
#  Ev::HTTP.new(
#    :get => "http://www.google.com/",
#    :load => lambda do |req|
#      cv.send req.body
#      cv.send "\0"
#    end
#  )
#  while data = cv.recv
#    puts data
#    break if data == "\0"
#  end
#  puts "EXIT!"
#end
#
#
