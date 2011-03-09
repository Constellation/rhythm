require 'rubygems'
require 'id3lib'
require 'kconv'
require 'iconv'
Dir.chdir(File.expand_path('~/music')) do
  pwd = Dir.pwd
  Dir.glob('*.mp3') do |file|
    tag = ID3Lib::Tag.new(File.join(pwd, file))
    puts tag.title.toutf8
  end
end

