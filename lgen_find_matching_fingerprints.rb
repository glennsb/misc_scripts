#! /usr/bin/env ruby
#
#  klap-lgen-clone-finder.rb
#
#  Created by Stuart B Glenn on 2008-01-07.
#  $Id:$
#  Copyright (c) 2008 Oklahoma Medical Research Foundation. All rights reserved.
#
# =Description
# A quick script to take the lgen style format file from klap and search for
# possible clones based on a fingerprint score
#
# == FORMAT LGEN INPUT
# Sample Group(family)	Sample ID	SNP Name	Allele1	Allele2
# ....


require 'getoptlong'
require 'ostruct'

class Snp 
  include Comparable
  
  attr_accessor :name, :chromosome, :position
  #
  # Create a new snp
  #
  def initialize(name, chromo, pos)
    (@name, @chromosome, @position) = name.downcase, chromo, pos
  end #initialize
  
  def to_s()
    name
  end #to_s
  
  #
  # Compare this to another SNP
  #
  def <=>(other)
    self.name <=> other.name
    # return 0 if self.name == other.name
    # if self.chromosome == other.chromosome then
    #   self.position <=> other.position
    # else
    #   self.chromosome <=> other.position
    # end
  end #<=>
end #snp


class Genotype
  attr_reader :snp, :alleles
  #
  # Create a new genotype at the snp with the alleles given
  #
  def initialize(snp,alleles)
    (@snp, @alleles) = snp, alleles
    @alleles.each_index do |a|
      @alleles[a].upcase!
      @alleles[a] = "0" unless %w/A T G C/.include?(@alleles[a])
    end
  end #initialize
  
  #
  # This genotype as a string, space separated, no calls translated to 0
  #
  def to_s()
    @alleles.join(" ")
  end #to_s
  
  #
  # Output the genotype as psuedo binary
  #
  def to_b()
    case @alleles.sort.join
      when "00"
        "0000"
      when "AA"
        "0001"
      when "AC"
        "0010"
      when "AG"
        "0011"
      when "AT"
        "0100"
      when "CC"
        "0101"
      when "CG"
        "0110"
      when "CT"
        "0111"
      when "GG"
        "1000"
      when "GT"
        "1001"
      when "TT"
        "1010"
      else
        "0000"
    end
  end
  
  #
  # Output the genotype as psuedo int
  #
  def to_i()
    case @alleles.sort.join
      when "00"
        0
      when "AA"
        1
      when "AC"
        2
      when "AG"
        3
      when "AT"
        4
      when "CC"
        5
      when "CG"
        6
      when "CT"
        7
      when "GG"
        8
      when "GT"
        9
      when "TT"
        10
      else
        0
    end
  end
  
  #
  # Compare if two are equal
  #
  def ==(geno_b)
    return false unless geno_b
    self.snp == geno_b.snp && self.alleles.sort == geno_b.alleles.sort
  end #==
end #Genotype

class Person
  include Comparable
  attr_reader :family, :number, :father, :mother, :gender, :phenotype, :genotypes

  #
  # create a person with a family, a number, father, mother, gender, and pheno
  #
  def initialize(fam,my_id,father_id,mohter_id,gender,phenotype)
    (@family, @number, @father, @mother, @gender, @phenotype ) = fam,my_id,father_id,mohter_id,gender,phenotype
    @genotypes = {}
  end #initialize

  #
  # The number of genotypes for this person
  #
  def num_genotypes()
    @genotypes.size
  end #num_genotypes

  #
  # Add a genotype to this person
  #
  def add_genotype(g)
    @genotypes[g.snp] = g
  end #add_genotype

  #
  # Print out the sample id for this person
  #
  def to_s()
    "#{@family}/#{@number}"
  end #to_s

  #
  # Compare this to another Person
  #
  def <=>(other)
    if self.family == other.family then
      self.number <=> other.number
    else
      self.family <=> other.family
    end
  end #<=>

  #
  # Return a binary like string of the genotypes
  #
  def genotype_binary_str(markers)
    if @binary_str then
      return @binary_str
    end
    @binary_str = ""
    markers.each do |m|
      g = @genotypes[m]
      if g
        @binary_str += g.to_b()
      else
        @binary_str += "0000"
      end
      
    end
    return @binary_str
  end #genotype_binary_str

  #
  # Get the binary str as a to_i(2)
  #
  def genotype_binary(markers)
    unless @binary_geno then
      @binary_geno = genotype_binary_str(markers).to_i(2)
    end
    return @binary_geno
  end #genotype_binary

  #
  # Get a single sum for the genotype info
  #
  def genotype_sum()
    sum = 0
    @num_no_calls = 0
    @genotypes.each do |snp,geno|
      geno_val = geno.to_i
      sum += geno_val
      @num_no_calls +=1 if 0 == geno_val
    end
    sum
  end #genotype_sum
  
  #
  # Get the number of no calls they had
  #
  def num_no_calls
    @num_no_calls
  end
  
  #
  # Get the number of valid calls
  #
  def num_calls()
    num_genotypes() - @num_no_calls
  end #num_calls

end #person

class ClonePair
  attr_reader :percent_similar, :subject_a, :subject_b
  #
  # Create one already
  #
  def initialize(a,b,similar)
    (@subject_a, @subject_b, @percent_similar) = a,b,similar
  end #initialize
  
  #
  # Compare to another, a pair is the same if a,b is the same as a,b or
  # b,a is the same as a,b
  #
  def ==(other)
    (
      (other.subject_a == @subject_a || other.subject_a == @subject_b) &&
      (other.subject_b == @subject_a || other.subject_b == @subject_b)
    )
  end #==
  
  #
  # Print out the pair
  #
  def to_s()
    "#{@subject_a.number}\t#{@subject_b.number}\t#{@percent_similar}"
  end #to_s
end


class LgenCloneFinderApp
	
	VERSION       = "0.1"
	REVISION_DATE = "2008-01-07"
	AUTHOR        = "Stuart B Glenn <glennsb@lupus.omrf.org>"
	COPYRIGHT     = "Copyright (c) 2008 Oklahoma Medical Research Foundation"
	
	MIN_PERECNT = 75.5
	
	#
	# returns version information string
	# based on CVS tags
	#
	def version
    	"Version: #{VERSION} Released: #{REVISION_DATE}\nWritten by #{AUTHOR}"
  end #version
    
  #
  # returns usage/help string
  #
  def usage
  	<<-USAGE
Usage: #{File.basename $0} -l LGEN_FILE
  -l | --lgen LGEN_FILE     The lgen data file
  -t | --target LGEN_FILE   A second lgen data file, to use as the compare to

USAGE
  end #usage
  
  #
  # process command line args
  #
  def get_options
  	opts = GetoptLong.new(
  	  ["--lgen","-l",GetoptLong::REQUIRED_ARGUMENT],
  	  ["--target","-t",GetoptLong::REQUIRED_ARGUMENT],
  		[ "--help","-H",GetoptLong::NO_ARGUMENT ],
  		[ "--version", "-v", GetoptLong::NO_ARGUMENT ]
  	)

  	opts.each do |opt, arg|
  		case opt
	      when "--lgen"
	        @options.lgen_file = arg
	      when "--target"
	        @options.target_lgen_file = arg
  			when "--help"
  				puts usage
  				exit 0
  			when "--version"
          puts "#{File.basename $0} - #{version}"
          puts ""
          puts "#{COPYRIGHT}. All Rights Reserved"
          puts "This software comes with ABSOLUTELY NO WARRANTY"
          exit 0
      	else
      	  puts usage
      		raise "Invalid option '#{opt}' with argument #{arg}."
  		end #case
  	end #each opt

  end #get_options
  
  # 
  # Initializer, scan CLI args and setup stuff
  #
  def initialize
    @options = OpenStruct.new()
    @people = []
    @people_b = []
    @snps = []
    
  	get_options()
  	
  	unless @options.lgen_file then
      puts usage()
      exit 1
    end

  end

	#
	# starts running/doing the actual work
	#
	def run
	  
	  print "Parsing lgen file #{@options.lgen_file}"
	  @people = parse_lgen(@options.lgen_file)
    puts ""
    
    if @options.target_lgen_file then
	    print "Parsing second lgen file #{@options.target_lgen_file}"
  	  @people_b = parse_lgen(@options.target_lgen_file)
      puts ""
    else
      @people_b = @people
    end
    
	  puts "Searching for clones"
	  @snps.sort!
	  
	  report_clones()
	
	end #run
	
	#
	# Process the people looking for possible clones
	#
	def report_clones()
	  total = 0
 	  @clone_pairs = []
 	  @num_snps_f = @snps.size.to_f
	  @people.each do |p|
	    print "."
      STDOUT.flush
      if 0 == ((total+1) % 1000) then
        puts ""
        STDOUT.flush
      end
      find_clones_of(p)
      total += 1
   end #each person

   puts ""
   puts @clone_pairs.join("\n")
   puts ""
   puts "#{@clone_pairs.size} possible clone pairs"
	end #report_clones
	
	#
	# Look for clones of person
	#
	def find_clones_of(person)
	  top_percent = MIN_PERECNT
	  score_sets = {}
	 
	  @people_b.each do |other|
	    #next if other == person
	    num_diff = (person.genotype_binary(@snps) ^ other.genotype_binary(@snps)).to_s(2).scan(/1/).size
	    percent_similar = (@num_snps_f - num_diff.to_f)/@num_snps_f*100.0
	   
	    if percent_similar > top_percent then
	      score_sets[percent_similar] = [] unless score_sets[percent_similar]
	      score_sets[percent_similar].push(other)
      end #if passes threshold
    end #each other person

    score_sets.keys.sort {|x,y| y <=> x}.slice(0,2).each do |percentage|
      score_sets[percentage].each do |possible_match_person|
        next if (person == possible_match_person && !@options.target_lgen_file)
        num_same_calls = 0
        @snps.each do |s|
          num_same_calls += 1 if possible_match_person.genotypes[s] == person.genotypes[s]
        end
        actual_percentage = ((num_same_calls.to_f/@num_snps_f*100.0)*100.0).round/100.0
        cp = ClonePair.new(person,possible_match_person,actual_percentage)
        @clone_pairs.push(cp) unless @clone_pairs.include?(cp)
      end #each possible matching person
    end #each top two score sets
   
	end #find_clones_of
	
	#
	# Process the lgen file and load up the search space
	#
	def parse_lgen(lgen_file)
	  people = []
    person = nil
    File.open(lgen_file).each_line do |line|
      parts = line.chomp.split(/\s/)
      if nil == person || parts[1] != person.number then
      # if nil == person || parts[1].to_i != person.number.to_i then
        if person then
          people.push(person)
          print "."
          STDOUT.flush
          if 0 == people.size % 1000 then
            puts ""
            STDOUT.flush
          end
    	    
        end
        #next/new person
        person = Person.new(parts[0],parts[1],nil,nil,nil,nil)
      end

      #Family	Sample ID	SNP Name	Allele1 - Top	Allele2 - Top
      snp = @snps.detect {|s| s.name == parts[2].downcase}
      unless snp then
        snp = Snp.new(parts[2], 0, 0)
        @snps.push(snp)
      end

      alleles = [parts[3].downcase,parts[4].downcase]
      person.add_genotype(Genotype.new(snp,alleles))      
    end #each line
    if person then
      people.push(person)
    end
    people
	end #parse_lgen
end #LgenCloneFinderApp


if $0 == __FILE__
    LgenCloneFinderApp.new.run
end