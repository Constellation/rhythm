require "rubygems"
require "libarchive_ruby"
#require "zipruby"
#require "zip/zipfilesystem"
require "pp"
require "kconv"
require "pathname"
require "benchmark"
require "dl/win32"
require "dl/import"
$KCODE = "u"

def test1
  path = File.expand_path("~/work/mfiler3-2.1.3.tgz")
  entries = []
  flag = true
  Archive.read_open_filename(path) do |arc|
    while entry =arc.next_header
      entries << entry
      if flag
        flag = false
        pp entry.pathname
      end
    end
  end
end

def test2
  path = File.expand_path("~/work/mod44048.zip")
  entries = []
  Zip::Archive.open(path) do |arc|
    n = arc.num_files
    n.times do |i|
      entry_name = arc.get_name(i)
      arc.fopen(entry_name) do |f|
        entries << f.stat
      end
    end
  end
  entries.each do |entry|
    pp entry.path
  end
end

def test3
  path = File.expand_path("~/work/mod44048.zip")
  entries = []
  Zip::ZipInputStream.open(path) do |arc|
    while entry = arc.get_next_entry
      entries << entry
    end
  end
  pp entries
end
# libarchive_ruby + rubyzip を使ったFile System View Wrapper(FSVW)
# 設計思想
# archive modeにはいるとnext_headerを使って全ファイル情報を読み出し, 仮想File Treeを作成する.
# writeされるばあいは全面的にrefreshする
# readのときはarchiveを開き, read_dataする
#
#printf "\x1b[10;10Htest\n"
# test1

#{Regexp.quote File::ALT_SEPARATOR}
def test5
  # chop_basename(path) -> [pre-basename, basename] or nil
  def chop_basename(path)
    if File::ALT_SEPARATOR
      sep_pat = /[#{Regexp.quote File::ALT_SEPARATOR}#{Regexp.quote File::SEPARATOR}]/
    else
      sep_pat = /#{Regexp.quote File::SEPARATOR}/
    end
    base = File.basename(path)
    if /\A#{sep_pat}?\z/o =~ base
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
  def dir_path path
    size = path.size
    p !size.zero? && path != '/' && path[size-1] == ?/
    if !size.zero? && path != '/' && path[size-1] == '/'
      return path.chop
    else
      return path
    end
  end
  sep_pat = /#{Regexp.quote File::SEPARATOR}/
  tests = File.expand_path("~/dev/rhythm/lib/rhythm/")
#  p split_names(tests)[1]
#  p tests.split(sep_pat)
#  p File.expand_path('/dev/').split(sep_pat)
#  p File.split(File.expand_path('/dev/'))
  tests = "/home/yusuke/dev/rhythm/lib/rhythm/"
  p dir_path(tests)
end


class Test
  @@count = 0
  def initialize test="ok"
    puts test
    ok? test
    @c = @@count += 1
  end
  def ok? ok="ok"
    puts ok
  end
  def to_s
    if @c > 2
      return "TEST#{@c}"
    else
      return ""
    end
  end
end
def humanize_number2 size
k = 1024
m = k * 1024
g = m * 1024
t = g * 1024
if size < k
  return sprintf('%iB', size)
elsif size < m
  if size < k * 10
    return sprintf('%.1fK', size.to_f / k)
  else
    return sprintf('%iK', size / k)
  end
elsif size < g
  if size < m * 10
    return sprintf('%.1fM', size.to_f / m)
  else
    return sprintf('%iM', size / m)
  end
elsif size < t
  if size < g * 10
    return sprintf('%.1fG', size.to_f / g)
  else
    return sprintf('%iG', size / g)
  end
else
  if size < t * 10
    return sprintf('%.1fT', size.to_f / t)
  else
    return sprintf('%iT', size / t)
  end
end
end
@@unit = %w(B K M G T)

def humanize_number size
count = 0
while size >= 1024 && count < 4
  size /= 1024.0
  count += 1
end
if 0 < size && size < 10
  sprintf("%.1f%s", size, @@unit[count])
else
  sprintf("%i%s", size, @@unit[count])
end
end

def test6
  Benchmark.bmbm do |x|
    x.report('1') do
      0.upto(100000) do |n|
        humanize_number(n)
      end
    end

    x.report('2') do
      0.upto(100000) do |n|
        humanize_number2(n)
      end
    end
  end
#  path = File.expand_path("~/work/mod44048.zip")
#  stat = File.stat path
#  p stat.mode
end

def test7
  begin
    api = Win32API.new('ifpng.dll', 'GetPluginInfo', ['i', 'p', 'i'], 'i')
    puts "test"
    arg = "\0" * 256
    result = api.call(0, arg, 256)
    puts result
  rescue => e
    puts e
  end
end

class CMigemo < Object
  extend DL::Importable
  def initialize
  end
end
def test8
  dlload 'ifpng.spi'
end

require "monitor"
class Counter < Monitor
  attr_reader :count
  def initialize
    @count = 0
    super
  end
  def up
    synchronize do
      @count += 1
    end
  end
end

def test9
  c = Counter.new
  thrs = [
    Thread.new { 100000.times { c.up } },
    Thread.new { 100000.times { c.up } }
  ]
  thrs.each(&:join)
  puts c.count
end
def test10
  n = 0
  Benchmark.bmbm do |x|
    x.report("1st"){ 1000000.times{ n.zero? } }
    x.report("2nd"){ 1000000.times{ n === 0  } }
  end
end

def test11
  lib = 'migemo.rb'
  if $:.detect{|path| File.exist?(File.join(path, lib))}
  end
end
require 'jcode'
def test12
  locale, charmap = ENV['LANG'].split('.')
  puts File.exist?("/usr/share/i18n/charmaps/#{charmap}.gz")
  puts Kconv::SJIS
  puts Kconv::EUC
  puts Kconv::UTF8
end
def test13

end
@@path = ENV["PATH"].split(':')
def command_defined cmd
  result = @@path.detect{|path|
    File.exist?(File.join(path, cmd))
  }
  if result
    puts File.join(result, cmd)
  end
end

def extend_glob text
  text = text.split(/\s/).collect! do |token|
    token = Regexp.escape(token)
    token.gsub!('\*', '.+')
    token.gsub!('\?', '.')
    token << '$'
  end.join('|')
  Regexp.compile(text)
end

def test13
  puts extend_glob('*')
end

require "iconv"
def test14
  Dir.foreach('/home/yusuke/work') do |file|
    puts Iconv.conv('UTF-8', 'UTF-8', Iconv.conv('UTF-8', 'UTF-8', file))
  end
end
require 'thread'
def test15
  testlambda = lambda do
    th = []
    [1, 2, 3, 4, 5, 6].each do|n|
      th << Thread.new do
        sleep(n * 0.1)
        puts n
      end
    end
    th.each(&:join)
  end
  testlambda2 = lambda do
    th = []
    %w(a b c d e f).each do|n|
      th << Thread.new do
        puts n
      end
    end
    th.each(&:join)
  end
  testlambda.call
  testlambda2.call
  puts "END"
end

def test16
  require "rgb"
  include Rhythm::RGB
#  text = nil
#  File.open('color.txt', 'rb') do |file|
#    text = file.read
#  end
#  lines = text.split(/\r\n|\r|\n/)
#  reg = /\s*([a-zA-Z]+)\s*(#[0-9a-zA-Z]+)\s*/
  #File.open('rgb_color.rb', 'wb') do |file|
#  count = 0
#  data = lines.map do |line|
#    match = reg.match(line)
#    if match
#      name = match[1].downcase
#      color = hex_color(match[2])
#      if name.size > count
#        count = name.size
#      end
#      [name, color]
#    end
#  end
#  File.open('rgb_color.rb', 'wb') do |file|
#    data.each do |n|
#      name, color = n
#      size = name.size
#      file.puts("\"#{name}\"#{" " * (count - size)} => #{color},")
#    end
#  end
  pp hex_color("#f0e68c")
  pp [0xf*16, 0xff, 0xe6, 0x8c]
end
module Kernel
  def _proc1
    Proc.new do |*args|
      yield *args
    end
  end
  def _proc2 &block
    Proc.new &block
  end
  def _proc3
    Proc.new
  end
end
def test17
  tmp1 = _proc1 do |i, j, k, l|
    p i, j
  end
  tmp2 = _proc2 do |i, j, k, l|
    p i, j
  end
  tmp3 = _proc3 do |i, j, k, l|
    p i, j
  end
  Benchmark.bmbm do |x|
#    GC.start
#    x.report('1') do
#      0.upto(100000) do |n|
#        tmp1 = _proc1 do |n|
#          n
#        end
#        tmp1.call(1, 2)
#      end
#    end
#    GC.start
#    x.report('2') do
#      0.upto(100000) do |n|
#        tmp2 = _proc2 do |n|
#          n
#        end
#        tmp2.call(1, 2)
#      end
#    end
#    GC.start
#    x.report('3') do
#      0.upto(100000) do |n|
#        tmp3 = _proc3 do |n|
#          n
#        end
#        tmp3.call(1, 2)
#      end
#    end
  end
end
def test18
  lines = [[], [], []]
  test = []
  test.push(*lines[1..1])
  p test
end
require 'stsize'
require 'locale'
def test19
  Locale.setlocale
#  a = "国".unpack('C*')
#  p 0x56fd
#  p 0xE5
#  p 0x9B
#  p 0xBD
#  p 'a'[0]
#  p a
#  p (((a[0] << 16)) + (( a[1]) << 8) + (( a[2]) << 0)).to_s(16)
#  p (((a[0] << 16)) + (( a[1]) << 8) + (( a[2]) << 0))
#  p ((((a[0] & 15) << 16)) + (((a[1] & 63)) << 8) + (((a[2] & 63)) << 0))
#  p ((((a[0] & 15) << 16)) + (((a[1] & 63)) << 8) + (((a[2] & 63)) << 0))
#  p "00000111".to_i(2)
#  p "国"[0],"国"[1],"国"[2]
#  p ("国"[0] + "国"[1] << 8 + "国"[2] << 16).to_s(16)
  p Delimiter::str_size("☆☆aし○", true)
  p Delimiter::is_ambiguous("●")
end
#test5
#test6
#test7
#test9
#test10
#test11
#test12
#test13
#test14
#test15
#test16
#test17
#test18
test19

#command_defined('screen')
