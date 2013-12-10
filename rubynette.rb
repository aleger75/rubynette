#!/usr/bin/env	ruby

def main
	rubynette = Rubynette.new
	rubynette.run
end

class Rubynette
	def	initialize
		@version = "1.0.0 alpha"
	end
	def hello
		puts "\e[36;1mRubynette\e[37;1m version \e[32;1m" + @version + "\e[0m"
	end
	def usage
		puts "Usage: rubynette [file1] [file2] [file3] ..."
		puts "Rubynette can guess your project config if there is a Makefile."
	end
	def run
		hello
		parse_args
	end
	def parse_args
		if ARGV.empty?
			if File.exist? "Makefile"
				do_file "Makefile"
			else
				puts "No file provided and no Makefile found."
				usage
			end
		end
		ARGV.each do |a|
			do_file(a)
		end
	end
	def do_file(file)
		if !(File.exist? file)
			puts "File " + file + " does not exist."
		else
			Parser.descendants.each do |parser|
				if parser.can_handle? file
					p = parser.new(self)
					p.handle file
					return
				end
			end
			puts "No parser found for file '" + file + "'."
		end
	end
end

class Parser
	def initialize(rubynette)
		@rubynette = rubynette
	end
	def self.descendants
		ObjectSpace.each_object(Class).select { |klass| klass < self }
	end
	def self.can_handle? (file)
		return false
	end
	def handle(filename)
		@filename = filename
		@file = File.open filename
		self.parse
		@file.close
	end
	def error(str)
		puts "[\e[31;1mERROR\e[0m] In " + @filename + " " + str
	end
end 

class ParserText < Parser
	def expand_tabs(s)
		s.gsub(/([^\t\n]*)\t/) do
			$1 + " " * (4 - ($1.size % 4))
		end
	end
	def parse
		check_header
		@file.each_with_index do |line, n|
			check_line(line, n)
		end
	end
	def check_line(line, n)
		if expand_tabs(line).size > 81
			error_line("Row have more than 80 characters.", n)
		end
		line.each_byte do |c|
			if c > 127
				error_line("Non-ASCII character.", n)
			end
		end
	end
	def check_header
		err = false
		lines = @file.readlines.slice(0..10)
		if lines.length != 11
			err = true
		end
		lines.each do |s|
			if expand_tabs(s).size != 81
				err = true
			end
		end
		if err
			error(": Missing header.")
		end
		@file.rewind
	end
	def error_line(str, line)
		error("at line " + (line + 1).to_s + " : " + str)
	end
end

class ParserSource < ParserText
	def initialize(r)
		super
		@func_count = 0
		@banned_keywords = [ "for", "do", "switch", "case", "default", "goto", "lbl" ]
		@keywords = [ "unsigned", "signed", "static", "const", "int", "short", "char",
					"float", "long", "double", "size_t", "auto", "struct", "typedef",
					"return", "break", "continue", "extern", "register", "restrict",
					"void", "enum", "union", "volatile", "inline" ]
	end
	def self.can_handle? (file)
		return File.extname(file) == ".c"
	end
	def check_line(line, n)
		super
		if line[0] == "}"[0] and !line.include?(";")
			@func_count += 1
		end
		if line[/^([\t ]+)\n$/]
			error_line("Empty line with trailing spaces or tabs.", n)
		elsif line[/^(.*)([\t ]+)\n$/]
			error_line("Trailing whitespace.", n)
		end
		if line[0, 2] == "/*" or line[0, 2] == "**" or line[0, 2] == "*/"
			return
		end
		line.gsub!(%r{"(.*)"}, "\"\"")
		line.gsub!(%r{'(.?)'}, "\' \'")
		if line.count(";") > 1
			error_line("More than one instruction.", n)
		end
		if line.include?("if ") or line.include?("while ")
			if !line[/^((\t)+)((else )?)if /] and !line[/^((\t)+)while /]
				error_line("Invalid text before control structure.", n)
			end
			if line.include?(";") or line.include?("{")
				error_line("No newline at end of control structure.", n)
			end
		end
		if line[/,(?![\n ])/]
			error_line("No space after comma.", n)
		end
		@banned_keywords.each do |w|
			reg = '[\t ]' + w + '[ \t\n(]'
			if line[/#{reg}/]
				error_line("Banned keyword '#{w}'.", n)
			end
		end
		@keywords.each do |w|
			reg = '^(([\t (])*)' + w + '(?![\t )])'
			if line[/#{reg}/]
				error_line("Keyword '#{w}' not followed by whitespace.", n)
			end
		end
		if !line[/^[\t ]/] and !line.include?("=") and line.count(",") > 3
			error_line("Function have too many parameters.", n)
		end
	end
	def parse
		super
		if @func_count > 5
			error " : More than 5 functions."
		end
	end
end

class ParserHeader < ParserSource
	def self.can_handle? (file)
		return (File.extname(file) == ".h")
	end
end

main

