#!/usr/bin/env ruby1.9

if ARGV.size < 3
  STDERR.puts "#{File.basename($0)} source replace source_col,dest_col ...."
  exit 1
end
source_file = File.open(ARGV.shift)
dest_file = File.open(ARGV.shift)

to_from = ARGV.map do |a|
  a.split(/,/).reverse.map {|s| s.to_i-1}
end

while (source_line = source_file.gets) do
  dest_line = dest_file.gets
  source_parts = source_line.chomp.split(/\s+/)
  dest_parts = dest_line.chomp.split(/\s+/)
  to_from.each do |ft|
    dest_parts[ft[0]] = source_parts[ft[1]]
  end
  puts dest_parts.join(" ")
end
source_file.close()
dest_file.close()
