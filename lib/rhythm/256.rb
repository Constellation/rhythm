def init_256_colors
  # colors 16-231 are a 6x6x6 color cube
  0.upto(5) do |red|
    0.upto(5) do |green|
      0.upto(5) do |blue|
  #              printf("\x1b]4;%d;rgb:%2.2x/%2.2x/%2.2x\x1b\\",
         printf("\x1b]4;%d;rgb:%x/%x/%x\x1b\\",
         16 + (red * 36) + (green * 6) + blue,
         (red ? (red * 40 + 55) : 0),
         (green ? (green * 40 + 55) : 0),
         (blue ? (blue * 40 + 55) : 0))
      end
    end
  end

  # colors 232-255 are a grayscale ramp, intentionally leaving out
  # black and white
  0.upto(23) do |gray|
    level = (gray * 10) + 8
  #          printf("\x1b]4;%d;rgb:%2.2x/%2.2x/%2.2x\x1b\\",
     printf("\x1b]4;%d;rgb:%x/%x/%x\x1b\\",
     232 + gray, level, level, level)
  end
end

# display the colors
init_256_colors

# first the system ones:
print "System colors:\n"
0.upto(7) do |color|
  print "\x1b[48;5;#{color}m#{color.to_s.ljust(3)}"
end
print "\x1b[0m\n"

8.upto(15) do |color|
  print "\x1b[48;5;#{color}m#{color.to_s.ljust(3)}"
end
print "\x1b[0m\n\n"

# now the color cube
print "Color cube, 6x6x6:\n";
0.upto(5) do |green|
  0.upto(5) do |red|
    0.upto(5) do |blue|
	    color = 16 + (red * 36) + (green * 6) + blue;
	    print "\x1b[48;5;#{color}m#{color.to_s.ljust(3)}"
    end
    print "\x1b[0m "
  end
  print "\n"
end

# now the grayscale ramp
print "Grayscale ramp:\n";
232.upto(255) do |color|
  print "\x1b[48;5;#{color}m#{color.to_s.ljust(3)}"
end
print "\x1b[0m\n"
print "\x1b[38;255m\x1b[48;7m"
print "\x1b[38;255m\x1b[48;7m"
