#!/usr/bin/env ruby

require "rubygems"
require "openssl"
require "base64"
require "digest/sha2"
require "thor"

BURP_VERSION = '0.0.6'

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
  include Thor::Actions
  default_task :generate

  BURP_CIPHER = "AES-256-CFB"
  NIL_SHA256 = "\343\260\304B\230\374\034\024\232\373\364\310\231o\271$'\256A\344d\233\223L\244\225\231\exR\270U"

  desc "generate", "Generates a new password (Default task)"
  method_option :wordlist, :type => :string, :aliases => "-W"
  method_option :words, :type => :numeric, :aliases => "-w", :default => 4
  method_option :separator, :type => :string, :aliases => "-s", :default => "-"
  method_option :alphanumeric, :type => :boolean
  def generate()
    sha256 = Digest::SHA256.new

    key = sha256.digest(ask "Enter your unique key: ")
    if key == NIL_SHA256
      say "Error: key must not be nil", :red
      exit
    end

    system "stty -echo" # don't echo our passphrase back to the terminal
    passphrase = sha256.digest(ask "Enter your secret passphrase: ")
    puts # new line
    system "stty echo"

    if passphrase == NIL_SHA256
      say "Error: passphrase must not be nil", :red
      exit
    end
    
    if options[:wordlist].nil?
      wordlist = DEFAULT_WORDLIST
    elsif options[:wordlist].match(/\.aes$/)
      e_wordlist = self.read_file(options[:wordlist])
      cipher = OpenSSL::Cipher.new(BURP_CIPHER)
      cipher.decrypt
      cipher.key = passphrase
      cipher.iv = e_wordlist.slice(0,16)
      d_wordlist = cipher.update(Base64.decode64(e_wordlist)) + cipher.final
      d_wordlist.gsub!(/^.{16}/,'') # remove iv prefix
      e_wordlist = nil

      wordlist = Array.new
      d_wordlist.scan(/^.*\n/).each { |w| wordlist.push w.chomp }
      d_wordlist = nil

      if wordlist.length < 256
        say "Error: Invalid wordlist", :red
        exit
      end
    else
      wordlist = self.wordlist_from_file(options[:wordlist])
    end

    hash = sha256.hexdigest("#{key}#{passphrase}")
    chunk_size = hash.length/options[:words]
    chunks = hash.scan(/.{#{chunk_size}}/)
    words = Array.new

    if options[:alphanumeric]
      nums = Array.new
    end

    for i in (0..(options[:words]-1))
      c = chunks[i]
      n = c.to_i(36).modulo(wordlist.length)
      words.push wordlist[n]

      if options[:alphanumeric]
        r = c.to_i(36).remainder(wordlist.length)
        nums.push r
      end
    end

    password = words.join(options[:separator])

    if options[:alphanumeric]
      password << options[:separator]
      nums.each do |n|
        z = 0
        n.to_s.scan(/.{1}/).each{ |x| z = z + x.to_i }
        password << z.to_s[0]
      end
    end

    say "Your password is: #{password}"
  end

  desc "encrypt FILE", "Encrypt a file using #{BURP_CIPHER} and your passphrase"
  def encrypt(file)
    contents = self.read_file(file)

    sha256 = Digest::SHA256.new
    system "stty -echo"
    passphrase = sha256.digest(ask "Enter your secret passphrase: ")
    puts
    system "stty echo"

    if passphrase == NIL_SHA256
      say "Error: passphrase must not be nil", :red
      exit
    end

    cipher = OpenSSL::Cipher.new(BURP_CIPHER)
    cipher.encrypt
    cipher.key = passphrase
    cipher.iv = initialization_vector = cipher.random_iv
    e_contents = cipher.update(contents) + cipher.final

    self.write_file("#{file}.aes", Base64.encode64(initialization_vector + e_contents))
  end

  desc "version", "BURP version number"
  def version
    puts "BURP: v#{BURP_VERSION} (https://github.com/jwmarshall/BURP)"
  end

  no_tasks do
    def wordlist_from_file(file)
      wordlist = Array.new
      file = "#{Dir.pwd}/#{file}" if ! file.match(/^\//)
      File.open(file, "r") do |f|
        f.each_line { |line| wordlist.push line.chomp }
      end
      if wordlist.length < 256
        say "Error: word list must have at least 256 words", :red
        exit
      end
      return wordlist
    end

    def read_file(file)
      file = "#{Dir.pwd}/#{file}" if ! file.match(/^\//)
      File.open(file, "r") do |f|
        return f.read
      end
    end

    def write_file(file, content)
      file = "#{Dir.pwd}/#{file}" if ! file.match(/^\//)
      if File.exists?(file)
        say "File exists!"
        exit
      end
      File.open(file, "w+") do |f|
        f.puts content
      end
    end
  end
end

BURP.start
