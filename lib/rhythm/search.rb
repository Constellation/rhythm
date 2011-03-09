# -*- coding: utf-8 -*-
require 'kconv'

module Rhythm
  class MigemoSearch < Object
    @@table = {
      "UTF8" => Kconv::UTF8,
      "SJIS" => Kconv::SJIS,
      "EUC"  => Kconv::EUC,
    }
    def initialize hash={}
      @static_dict = hash[:static]
      @dict_cache = hash[:cache]
      raise "dict not found" unless @static_dict && dict_cache
      @optimization = 2
      @cache = {}
      @kcode = $KCODE
      @conv = @@table[@kcode]
    end
    def search pattern
      if @cache.has_key?(pattern)
        return @cache[pattern]
      else
        begin
          $KCODE = 'e'
          euc_pattern = pattern.toeuc
          migemo = Migemo.new(@static_dict, euc_pattern)
          migemo.dict_cache = @dict_cache if @dict_cache
          migemo.optimization = @optimization
          migemo.with_paren = false
          return @cache[pattern] = Kconv.kconv(migemo.regex, @conv, Kconv::EUC)
        ensure
          $KCODE = @kcode
        end
      end
    end
  end
  class CMigemoSearch < Object
    @@table = {
      "UTF8" => 'utf-8',
      "SJIS" => 'cp932',
      "EUC"  => 'euc-jp',
    }
    def initialize hash=nil
      if hash
        migemo = hash[:migemo]
        han2zen = hash[:han2zen]
        hira2kata = hash[:hira2kata]
        roma2hira = hash[:roma2hira]
        unless migemo && han2zen && hira2kata && roma2hira
          raise ArgumentError, "dicts not enough"
        else
          hash = {
            migemo    => CMigemo::MIGEMO,
            han2zen   => CMigemo::HAN2ZEN,
            hira2kata => CMigemo::HIRA2KATA,
            roma2hira => CMigemo::ROMA2HIRA,
          }
        end
      else
        hash = migemo_dict
      end
      @cmigemo = CMigemo.new
      hash.each do |dict_file, type|
        @cmigemo.load(type, dict_file)
      end
      @cache = {}
    end
    def search pattern
      if @cache.has_key?(pattern)
        return @cache[pattern]
      else
        return @cache[pattern] = @cmigemo.query(pattern)
      end
    end
    private
    def migemo_dict dict
      std = "/usr/local/share/migemo/"
      path = File.join(std, @@table[$KCODE])
      if File.exist? path
        return {
          File.join(path, "migemo-dict")   => CMigemo::MIGEMO,
          File.join(path, "han2zen.dat")   => CMigemo::HAN2ZEN,
          File.join(path, "hira2kata.dat") => CMigemo::HIRA2KATA,
          File.join(path, "roma2hira.dat") => CMigemo::ROMA2HIRA,
        }
      else
        raise ArgumentError, "dicts not found"
      end
    end
  end
  module Search
  end
end
