#!/usr/bin/env ruby
#
TESTS = {
  "BURDEN" => 6,
  "CALPHA" => 6,
  "FW" => 6,
  "SUMSTAT" => 6,
  "UNIQ" => 6,
  "VASSOC" => 20,
  "VT" => 6
}

CHROMOSOMES = %w/1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y/

pval_target = ARGV.shift
file_prefix = ARGV.shift

tests_to_do = ARGV.map {|t| t.upcase}
if tests_to_do == nil || tests_to_do.size == 0 then
  tests_to_do = TESTS.keys
end

TESTS.each do |test,column|
  next unless tests_to_do.include?(test)
  CHROMOSOMES.each do |chr|
    file = "#{file_prefix}#{chr}.#{test}"
    cmd = "awk -F '\\t' '{if($#{column} < #{pval_target}) print $0}' #{file}"
    #$stderr.puts cmd
    system(cmd)
    sleep(0.5)
  end
end
