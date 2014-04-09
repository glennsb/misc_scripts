#! /usr/bin/env ruby
#
#  check_plink_ped
#
#  Created by Stuart B Glenn on 2007-12-31.
#  $Id:$
#  Copyright (c) 2007 Oklahoma Medical Research Foundation. All rights reserved.
#
# =Description
# A quick hack of a script to compare a lgen file (bead studio?) to a plink
# ped file to make sure all the genotypes match correctly
#
# == FORMAT PED INPUT
# ID Family_ID	Person_ID	Paternal_ID	Maternal_ID	Sex(1=Male; 2=Female; other=unknown)	Phenotype(0=unknown, 1 unaffected, 2 affected) Genos
# ....
#
# == FORMAT LGEN INPUT
# Sample Group(family)	Sample ID	SNP Name	Allele1	Allele2
# ....
#
# == FORMAT MAP INPUT
# Chr	Name  Dist	Position
# ....
#

require 'getoptlong'
require 'ostruct'

class Array
  def push_if_not(a)
    self.push(a) unless detect {|m| m == a}
  end
end

class Snp 
  include Comparable
  
  attr_accessor :name, :chromosome, :position
  #
  # Create a new snp
  #
  def initialize(name, chromo, pos)
    (@name, @chromosome, @position) = name.downcase, chromo, pos
  end #initialize
  
  #
  # 
  #
  def to_s()
    name
  end #to_s
  
  #
  # Compare this to another SNP
  #
  def <=>(other)
    return 0 if self.name == other.name
    if self.chromosome == other.chromosome then
      self.position <=> other.position
    else
      self.chromosome <=> other.position
    end
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
    @genotypes = []
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
    @genotypes.push(g)
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
    b = ""
    markers.each do |m|
      g = @genotypes[m]
      if g
        b += g.to_b()
      else
        b += "0000"
      end
      
    end
    b
  end #genotype_binary_str

  #
  # Get a single sum for the genotype info
  #
  def genotype_sum()
    sum = 0
    @num_no_calls = 0
    @genotypes.each do |geno|
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

class PlinkPedCheckerApp
	
	VERSION       = "1.0"
	REVISION_DATE = "2007-12-31"
	AUTHOR        = "Stuart B Glenn <glennsb@lupus.omrf.org>"
	COPYRIGHT     = "Copyright (c) 2007 Oklahoma Medical Research Foundation"
	
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
Usage: #{File.basename $0} -m MAP_FILE -p PED_FILE -l LGEN_FILE
  -p | --ped PED_FILE       The plink formatted ASCII ped file
  -m | --map MAP_FILE       The plink formatted marker map file
  -l | --lgen LGEN_FILE     The lgen data file
  --skip LIST               List of markers to skip

USAGE
  end #usage
    
  #
  # process command line args
  #
  def get_options
  	opts = GetoptLong.new(
  	  ["--ped","-p",GetoptLong::REQUIRED_ARGUMENT],
  	  ["--map","-m",GetoptLong::REQUIRED_ARGUMENT],
  	  ["--lgen","-l",GetoptLong::REQUIRED_ARGUMENT],
	    ["--skip",GetoptLong::REQUIRED_ARGUMENT],
  	  ["--mode",GetoptLong::REQUIRED_ARGUMENT],
  		[ "--help","-H",GetoptLong::NO_ARGUMENT ],
  		[ "--version", "-v", GetoptLong::NO_ARGUMENT ]
  	)
  	
  	opts.each do |opt, arg|
  		case opt
  		  when "--skip"
  		    @options.skip_file = arg
  		  when "--mode"
  		    case arg
  		      when /slow_compare/i
  		        @options.mode = :compare
  		      when /binary/i
  		        @options.mode = :binary
  		      when /sums/i
  		        @options.mode = :sums
	        end
  		  when "--ped"
  		    @options.ped_file = arg
		    when "--map"
		      @options.map_file = arg
	      when "--lgen"
	        @options.lgen_file = arg
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
  	
  end #getOptions
  
  # 
  # Initializer, scan CLI args and setup stuff
  #
  def initialize
    @options = OpenStruct.new()
    @options.mode = :lgen_output
    
  	get_options()
  	
  	#unless @options.ped_file && @options.map_file then
    #   puts usage()
    #   exit 1
    # end
        
    @snps = []
    @people = []
  end

	#
	# starts running/doing the actual work
	#
	def run
	  @skip_markers = []
	  parse_skip_list() if @options.skip_file
    parse_map_file()
    parse_geno_file() if @options.lgen_file
    parse_ped_file() if @options.ped_file
	end #run
	
	
	#
  # How many SNPs have we seen
  #
  def num_snps()
    @snps.size
  end #num_snps
  
	#
  # Get the size of the data set, ie the number of snps
  #
  def num_people()
    @people.size
  end #size
  
  #
  # Get the number of genotypes read ing
  #
  def num_genotypes()
    @people.inject(0) {|sum,p| sum += p.num_genotypes }
  end #num_genotypes
  
  
	private
	
  #
  # Read in the genotypes
  #
  def person_from_geno_file(target_family, target_subject)
    person = nil
    sum = 0
    no_calls = 0
    File.open(@options.lgen_file).each_line do |line|

      parts = line.chomp.split(/\s/)
      
      if parts[0].to_i == target_family && parts[1].to_i == target_subject
        #Family	Sample ID	SNP Name	Allele1 - Top	Allele2 - Top
#        snp = @snps.detect {|s| s.name == parts[2].downcase}
#        raise "Unknown snp #{parts[2]} at #{lineno} of #{@opts.geno_file}" unless snp

        person = Person.new(parts[0],parts[1],nil,nil,nil,nil) unless person

        alleles = [parts[3],parts[4]]
        person.add_genotype(Genotype.new(nil,alleles))
      else
        if person then
          return person
        end
      end
    end #each line
    person
  end #par
  	

  #
  # For a person, output sum summary information
  # person sum num_no_call num_call
  #
  def output_sums(person,output)
    puts "#{person.number} #{person.genotype_sum()} #{person.num_no_calls} #{person.num_calls}"
    #flush
  end #output_sums

  #
  # Read in the genotypes
  #
  def parse_geno_file()
    person = nil
    File.open(@options.lgen_file).each_line do |line|

      parts = line.chomp.split(/\s/)
      
      if nil == person || parts[1].to_i != person.number.to_i then
        if person then
            output_sums(person,@lgen_sum_output)
        end
        #next/new person
        person = Person.new(parts[0],parts[1],nil,nil,nil,nil)
      end

      alleles = [parts[3],parts[4]]
      person.add_genotype(Genotype.new(nil,alleles)) unless @skip_markers.include?(parts[2].downcase)      
    end #each line
    if person then
      #there was one before, so output this one now
      if :binary == @options.mode
        compare_plink(person)
      elsif :sums == @options.mode
        output_sums(person,@lgen_sum_output)
      end
    end
  end #par

  #
  # Compare this persont to someone in the plink file
  #
  def compare_plink(person)
#    print "#{person} looking for match..."
    plink_person = person_from_plink_file(person.number.to_i)
#    puts "Checking comparison" 
    approx_num_different = person.genotype_binary_str(@snps).to_i(2) ^ plink_person.genotype_binary_str(@snps).to_i(2)
    print "#{person} "
    if 0 == approx_num_different then
      puts "matches"
    else
      puts "mismatch"
    end
    # puts "#{person} #{approx_num_different}"
    # puts ""
    # puts person.genotype_binary_str(@snps)
    # puts plink_person.genotype_binary_str(@snps)
    # puts ""
  end #compare_plink

  #
  # Find the person in the plink file
  #
  def person_from_plink_file(target_subject)
    File.open(@options.ped_file).each_line do |line|
      parts = line.chomp.split(/\s/)
      #Family_ID Person_ID	Paternal_ID	Maternal_ID	Sex Phenotype calls
      next unless parts[1].to_i == target_subject
      
      person = Person.new(parts[0],parts[1],parts[2],parts[3],parts[4],parts[5])
      offset = 6
      marker = 0
      alleles = nil
      parts.slice(offset,parts.size).each_with_index do |c,i|
        if nil == alleles then
          alleles = [c]
        else
          alleles.push(c)
          geno = Genotype.new(nil,alleles)
          person.add_genotype(geno)
          marker+=1
          alleles = nil
        end
      end
      return person
    end
    return nil
  end #person_from_plink_file

  #
  # Do the comparison, find the match, print out stuff
  #
  def compare(person)
    lgen_person = person_from_geno_file(person.family.to_i, person.number.to_i)
    errors = []
    if lgen_person then
      @snps.each_with_index do |snp,i|
        geno_ped = person.genotypes[i]
        geno_lgen = lgen_person.genotypes[i]
        if nil == geno_ped || nil == geno_lgen then
          unless geno_lgen
            puts "FAILED: #{person}: #{snp}: Can't find genotype in lgen"
            errors.push("FAILED: #{person}: #{snp}: Can't find genotype in lgen")
          end
          unless geno_ped
            puts "FAILED: #{person}: #{snp}: Can't find genotype in ped" 
            errors.push("FAILED: #{person}: #{snp}: Can't find genotype in ped")
          end
        else
          unless geno_lgen == geno_ped
            puts "FAILED: #{person}: #{snp}: Don't match #{geno_lgen} vs #{geno_ped}" 
            errors.push("FAILED: #{person}: #{snp}: Don't match #{geno_lgen} vs #{geno_ped}")
          end
        end
      end #each snp
      if 0 == errors.size then
        puts "PASS: #{person}"
      else
        puts "FAILED: #{person}: #{errors.size} errors"
      end
    else
      puts "FAILED: #{person}: ALL: Can't find matching lgen"
    end
  end #compare_person

	#
  # Read in the pedigree info
  #
  def parse_ped_file()
    File.open(@options.ped_file).each_line do |line|
      parts = line.chomp.split(/\s/)
      #Family_ID Person_ID	Paternal_ID	Maternal_ID	Sex Phenotype calls
      person = Person.new(parts[0],parts[1],parts[2],parts[3],parts[4],parts[5])
      offset = 6
      marker = 0
      alleles = nil
      parts.slice(offset,parts.size).each_with_index do |c,i|
        raise "Nil marker at #{line} for #{@snps.inspect}, at #{marker}" unless @snps[marker]
#        marker_name = parts[@snps[marker]].name
        if nil == alleles then
          alleles = [c]
        else
          alleles.push(c)
          geno = Genotype.new(nil,alleles)
          person.add_genotype(geno) #unless @skip_markers.include?(marker_name)
          marker+=1
          alleles = nil
        end
      end
      
      if :compare == @options.mode
        compare(person)
      elsif :lgen_output == @options.mode
        @snps.each do |snp|
          puts "#{person.family}\t#{person.number}\t#{snp}\t#{person.genotypes[snp].alleles.join("\t")}"
        end
      elsif :sums == @options.mode
        output_sums(person,@plink_sum_output)        
      else
        @people.push(person)
      end
      
    end #each line
  end #parse_p
	
	#
  # Read in the map file to get the info on the SNPs
  #
  def parse_map_file()
    File.open(@options.map_file).each_line do |line|      
      parts = line.chomp.split(/\s/)
      snp = Snp.new(parts[1],parts[0],parts[3])
      @snps.push(snp)
    end #each line
  end #parse_map_file
  
  #
  # 
  #
  def parse_skip_list()
    @skip_markers = []
    File.open(@options.skip_file).each_line do |line|      
      parts = line.chomp.split(/\s/)
      @skip_markers.push(parts[0].downcase)
    end #each line
  end #parse_skip_list
  
end #PlinkPedCheckerApp


if $0 == __FILE__
    PlinkPedCheckerApp.new.run
end