#!/usr/bin/env ruby #********************************************************* #
#                                                                              #
#                                                         :::      ::::::::    #
#    rubynette.rb                                       :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: mbacoux <marvin@42.fr>                     +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2013/12/10 15:24:10 by mbacoux           #+#    #+#              #
#    Updated: 2014/01/02 22:12:23 by mbacoux          ###   ########.fr        #
#                                                                              #
# **************************************************************************** #


def main
	rubynette = Rubynette.new
	rubynette.run
end

class Rubynette
	def	initialize
		@version = "1.1.1 Lemon"
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
				if parser.can_handle? file and parser.handle_file_type? file
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
		return false;
	end
	def self.handle_file_type? (file)
		return false
	end
	def handle(filename)
		@filename = filename
		@file = File.open filename
		sp = " " * 15
		puts "\e[37;1m[ \e[35;1m ----------         PARSING FILE #{File.basename(filename.upcase)} #{sp[0, (sp.size - File.basename(filename).size)]} ---------- \e[37;1m]\e[0m"
		parse
		@file.close
	end
	def error(str)
		puts "[\e[31;1m  ERROR  \e[0m] In " + @filename + " " + str
	end
	def warning(str)
		puts "[\e[33;1m WARNING \e[0m] In " + @filename + " " + str
	end
end 

class ParserFile < Parser
	def self.handle_file_type? (file)
		return File.file? file
	end
end

class ParserDir < Parser
	def self.can_handle? (file)
		return true
	end
	def self.handle_file_type? (file)
		return File.directory? file
	end
	def handle (file)
		Dir.foreach file do |f|
			if (f[0] != "."[0])
				@rubynette.do_file((file == "/" ? "" : file) + "/" + f)
			end
		end
	end
end

class ParserBin < ParserFile
	def self.can_handle? (file)
		ext = File.extname(file)
		if (ext == ".a" or ext == ".o" or ext == ".dylib" or ext == ".so")
			return true
		elsif File.executable? file
			return true
		end
		return false
	end
	def parse
		puts "Your binary file '#{File.basename(@filename)}' contains the following calls :"
		calls = `nm -gu #{@filename} | sed 's/\$.*//' | sed '/^_/!D' | sed '/^__/D' | cut -c 2- | sed '/^ft_/D' | sort -u`
		if calls
			calls.each do |c|
				puts "--> #{c}"
			end
		end
	end
end

class ParserText < ParserFile
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
		else
			check_filename(lines[3])
		end
		@file.rewind
	end
	def check_filename(line)
		name = (line.split)[1]
		if name != File.basename(@filename)
			warning("Filename does not match header.")
		end
	end
	def error_line(str, line)
		error("at line " + (line + 1).to_s + " : " + str)
	end
end

class ParserSource < ParserText
	def initialize(r)
		super
		@func_count = 0
		@line_count = -1
		@space_indent = 0
		@banned_keywords = [ "for", "do", "switch", "case", "default", "goto", "lbl" ]
		@keywords = [ "unsigned", "signed", "static", "const", "int", "short", "char",
					"float", "long", "double", "size_t", "auto", "struct", "typedef",
					"return", "break", "continue", "extern", "register", "restrict",
					"void", "enum", "union", "volatile", "inline" ]
		@binary_ops = [ ">>=", "<<=", ">>", "<<", "&&", "||", "==", "+=", "-=", "*=", "/=", "%=",
						">=", "<=", "?", ":", "!=", "&=", "|=", "^=", "^", "|",
						"=", "/", ">", "<"]
	end
	def self.can_handle? (file)
		return (File.extname(file) == ".c" or File.extname(file) == ".h")
	end
	def is_operator?(str, op)
		find = nil;
		if str["->"]
			return false
		end
		@binary_ops.each do |o|
			if str[o]
				find = o
				break
			end
		end
		return (find == op)
	end
	def get_def_indent(line)
		str = line[/[a-z]/]
		if str != nil
			return line.index(str) - 1
		else
			return nil
		end
	end
	def get_def_word(line)
		start = get_def_indent(line)
		len = line[/(([a-z])+)/]
		if start == nil or len == nil
			return nil
		end
		return line[start + 1, len.size]
	end
	def check_line(line, n)
		super
		if line[0, 2] == "/*" or line[0, 2] == "**" or line[0, 2] == "*/"
			return
		end
		if line.include? "//"
			error_line("C++ style comments are not allowed.", n)
			return
		end
		if line[0] == "}"[0] and !line.include?(";")
			@func_count += 1
		end
		if line[/^([\t ]+)\n$/]
			error_line("Empty line with trailing spaces or tabs.", n)
		elsif line[/^(.*)([\t ]+)\n$/]
			error_line("Trailing whitespace.", n)
		end	
		line.gsub!(%r{"(.*)"}, "\"\"")
		line.gsub!(%r{'(.?)'}, "\' \'")
		if line.count(";") > 1
			error_line("More than one instruction.", n)
		end
		if (line.include?("if ") or line.include?("while ")) and line[0] != "#"[0]
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
			reg = '^(([\t (])*)' + w + '[;(]'
			if line[/#{reg}/]
				error_line("Keyword '#{w}' not followed by whitespace.", n)
			end
		end
		if !line[/^[\t ]/] and !line.include?("=") and line.count(",") > 3
			error_line("Function have too many parameters.", n)
		end
		if line == "}\n"
			if @line_count > 25
				error_line("Function have " + @line_count.to_s + " lines.", n);
			end
			@line_count = -1
		end
		if @line_count != -1
			@line_count += 1
		end
		if line == "{\n"
			@line_count = 0
		end
		if line[/sizeof(?![(])/]
			error_line("Whitespace after sizeof.", n)
		end
		@binary_ops.each do |o|
			if (line[0] == "#"[0])
				break
			end
			reg = '(?![ \n])' + o + '(?![ \n])'
			i = line.index(/#{reg}/)
			if i and is_operator?(line[i - 1, 4], o)
				error_line("Missing spaces around operator '#{o}'.", n);
			end
		end
		if line[0] == "#"[0]
			word = get_def_word(line)
			if (word == nil)
				error_line("Lone sharp.", n)
			else
				if (word == "endif")
					@space_indent -= 1
				end
				check = @space_indent
				if word == "else" or word == "elif"
					check -= 1
				end
				if (get_def_indent(line) != check)
					error_line("Bad sharp indent, should be #{check.to_s}.", n)
				end
				if word == "if" or word == "ifdef" or word == "ifndef"
					@space_indent += 1
				end
			end
		end
	end
	def parse
		super
		if @func_count > 5
			error " : More than 5 functions."
		end
	end
end

class ParserMakefile < ParserText
	def self.can_handle? (file)
		return (File.basename(file) == "Makefile")
	end
	def handle (file)
		path = File.dirname(file)
		files = `make -Bn -C #{path} | grep -o "[.a-zA-Z0-9_/-]*\\.c"`
		files.each do |f|
			@rubynette.do_file(path + (path == "/" ? "" : "/") + f.gsub(/[\n]/, ''));
		end
		files = `make -Bn -C #{path} | grep -o "\\-I[ ]*[.a-zA-Z0-9_/-]*" | sed "s/-I//" | tr -d " " | sort -u`
		files = files + "."
		files.each do |f|
			dir = Dir.foreach(path + (path == "/" ? "" : "/") + f.gsub(/[\n]/, "")) do |d|
				if File.extname(path + (path == "/" ? "" : "/") + f.gsub(/[\n]/, "") + "/" + d.gsub(/[\n]/, "")) == ".h"
					@rubynette.do_file(path + (path == "/" ? "" : "/") + f.gsub(/[\n]/, "") + "/" + d.gsub(/[\n]/, ""))
				end
			end
		end
		files = `make -Bn -C #{path} | grep -o "make -C [.a-zA-Z0-9_/-]*" | cut -c 8- | tr -d " "`
		files.each do |f|
			@rubynette.do_file(path + (path == "/" ? "" : "/") + f.gsub(/[\n]/, "") + "/" + "Makefile")
		end
	end
end

main

