#!/usr/bin/env ruby1.9
#
require 'zlib'
require 'fileutils'

infile = ARGV.shift
raise "Missing input file" unless infile

outputs = {}
newdir = File.join(File.dirname(infile),"orig")
Dir.mkdir(newdir) unless File.exists?(newdir)

mtime = File.mtime(infile)
(lgscode,read) = File.basename(infile,".txt.gz").scan(/(lgs\d+)_(\d)/).first

newfile = File.join(File.dirname(infile),"orig",File.basename(infile))
FileUtils.mv(infile,newfile)

File.open(newfile) do |io|
  input = Zlib::GzipReader.new(io)
  input.each do |first_line|
    lane = first_line.split(/:/)[1].to_i
    read = first_line.chomp.split(/:/)[-1].split(/\//).last.to_i
    bases = input.gets
    name = input.gets
    quality = input.gets

    key="#{lane}_#{read}"
    unless outputs[key]
      orig_name = "#{lgscode}_#{lane}_#{read}.txt"
      outputs[key] = Zlib::GzipWriter.open(File.join(File.dirname(infile),"#{orig_name}.gz"))
      outputs[key].mtime = mtime
      outputs[key].orig_name = orig_name
    end
    outputs[key].write first_line
    outputs[key].write bases
    outputs[key].write name
    outputs[key].write quality
    break if input.eof?
  end
#  input.close
end

outputs.each do |l,o|
  o.close
end
