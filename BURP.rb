#!/usr/bin/env ruby

require "rubygems"
require "digest/sha1"
require "thor"

DEFAULT_WORDLIST = %w{
  abode abyss air angle apple arm army arrow artist author avenue
  baby bandit banker banner bard baron barrel beast belfry bird
  blood board body book bosom boss bottle boy brain breeze bronze
  cabin candy cane car cash cat cell cellar chair chasm chief child
  chin cigar circle city claw clock coast coffee coin colony comedy
  cord core corn corner corpse cotton cradle crime damsel dawn dirt
  doctor doll dollar door dove drama dream dress dust earth engine
  errand fabric feline flag flask flesh flower fork form fowl fox
  friend frog fur galaxy garden garret geese girl goblet gold gore
  grass green hall hamlet hammer harp health hoof hotel hound house
  hurdle icebox infant ink insect iron jail judge jury keg kettle
  king kiss lad lark lawn lemon letter lice limb lime link lip
  locker lord lump maiden mantle mast master meadow mirage money
  monk month morgue moss mother mucus murder nail nephew noose nun
  nymph oats odour opium owner oxygen palace peach pelt pepper
  piano pipe piston plain plank poet poetry pole poster prayer
  priest prison pupil python queen rattle reflex revolt ritual
  river robber rock rod rosin rubble salad salary salute sauce sea
  season seat serf ship shock shriek singer skin skull sky slush
  snake sonata speech spire spray stain star stone street string
  stub suds sugar sultan sunset swamp table tank temple thief thorn
  ticket tidbit toast tomb tool tower tree troops truck vacuum
  vapour vessel vest victim vision volume warmth water weapon
  wench whale wheat wife wigwam window wine woman woods world yacht
}

class BURP < Thor
  default_task :generate

  desc "generate", "Generates a new password"
  method_option :wordlist, :type => :string, :aliases => "-W"
  method_option :words, :type => :numeric, :aliases => "-w", :default => 4
  method_option :seperator, :type => :string, :aliases => "-s", :default => "-"
  def generate()
    if options[:wordlist].nil?
      wordlist = DEFAULT_WORDLIST
    else
      wordlist = Array.new
      if ! options[:wordlist].match(/^\//)
        File.open("#{Dir.pwd}/#{options[:wordlist]}", "r") do |f|
          f.each_line { |line| wordlist.push line.chomp }
        end
      end
    end

    if wordlist.length < 256
      say "Error: wordlist must have at least 256 words", :red
      exit
    end

    if options[:words] != 4 && options[:words] != 5
      say "Error: words in hash must be either 4 or 5", :red # for now avoid lost bits (remainder)
      exit
    end

    key = Digest::SHA1.hexdigest(ask "Enter your unique key: ")
    if key == "da39a3ee5e6b4b0d3255bfef95601890afd80709" # nil sha1
      say "Error: key must not be nil", :red
      exit
    end

    system "stty -echo" # don't echo our passphrase back to the terminal
    passphrase = Digest::SHA1.hexdigest(ask "Enter your secret passphrase: ")
    puts # new line
    system "stty echo"

    if passphrase == "da39a3ee5e6b4b0d3255bfef95601890afd80709" # nil sha1
      say "Error: passphrase must not be nil", :red
      exit
    end

    hash = Digest::SHA1.hexdigest("#{key}#{passphrase}")
    chunk = hash.length/options[:words]
    array = Array.new
    chars = hash.scan(/.{#{chunk}}/)

    for i in (0..(options[:words]-1))
      c = chars[i]
      n = c.to_i(36).modulo(wordlist.length)
      array.push wordlist[n]
    end

    password = array.join(options[:seperator])
    say "Your password is: #{password}"
  end
end

BURP.start
