# vim: fileencoding=utf-8
# Encoding check for ruby 1.9
$KCODE="u" unless Object.const_defined? :Encoding

$:.unshift(File.dirname(__FILE__) + "/rhythm") unless
  $:.include?(File.dirname(__FILE__) + "/rhythm") || $:.include?(File.expand_path(File.dirname(__FILE__) + "/rhythm"))

