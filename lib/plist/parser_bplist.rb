#!/usr/bin/env ruby
#
# = plist
#
# Copyright 2006-2010 Ben Bleything and Patrick May
# Distributed under the MIT License
#
# Merged ruby-plist-readonly bplist from http://code.google.com/p/ruby-plist/source/list by aquasync -mosen
# Added support for data, date and utf string - mosen
=begin
http://www.opensource.apple.com/source/CF/CF-550/CFBinaryPList.c

HEADER
	magic number ("bplist")
	file format version

OBJECT TABLE
	variable-sized objects

	Object Formats (marker byte followed by additional info in some cases)
	null	0000 0000
	bool	0000 1000			// false
	bool	0000 1001			// true
	fill	0000 1111			// fill byte
	int	0001 nnnn	...		// # of bytes is 2^nnnn, big-endian bytes
	real	0010 nnnn	...		// # of bytes is 2^nnnn, big-endian bytes
	date	0011 0011	...		// 8 byte float follows, big-endian bytes
	data	0100 nnnn	[int]	...	// nnnn is number of bytes unless 1111 then int count follows, followed by bytes
	string	0101 nnnn	[int]	...	// ASCII string, nnnn is # of chars, else 1111 then int count, then bytes
	string	0110 nnnn	[int]	...	// Unicode string, nnnn is # of chars, else 1111 then int count, then big-endian 2-byte uint16_t
		0111 xxxx			// unused
	uid	1000 nnnn	...		// nnnn+1 is # of bytes
		1001 xxxx			// unused
	array	1010 nnnn	[int]	objref*	// nnnn is count, unless '1111', then int count follows
		1011 xxxx			// unused
	set	1100 nnnn	[int]	objref* // nnnn is count, unless '1111', then int count follows
	dict	1101 nnnn	[int]	keyref* objref*	// nnnn is count, unless '1111', then int count follows
		1110 xxxx			// unused
		1111 xxxx			// unused

OFFSET TABLE
	list of ints, byte size of which is given in trailer
	-- these are the byte offsets into the file
	-- number of these is in the trailer

TRAILER
	byte size of offset ints in offset table
	byte size of object refs in arrays and dicts
	number of offsets in offset table (also is number of objects)
	element # in offset table which is top level object
	offset table offset

typedef struct {
    uint8_t	_unused[6];
    uint8_t	_offsetIntSize;
    uint8_t	_objectRefSize;
    uint64_t	_numObjects;
    uint64_t	_topObject;
    uint64_t	_offsetTableOffset;
} CFBinaryPlistTrailer;
=end

module Plist
  require 'ostruct'
  require 'strscan'
  
  def Plist::parse_bplist( data )
    obj = BPlist.load data
  end
  
  class BPlist
  	attr_reader :data, :trailer, :offtab, :unpack_offset_char, :unpack_ref_char

  	def initialize data
  		@data = data
  		raise "expected 'bplist' signature #{@data[0..7]}" unless @data[0..7] == 'bplist00'

  		# expand trailer into an openstruct
  		trailer = @data[-32..-1]
  		@trailer = OpenStruct.new Hash[
  			*%w[int_size ref_size num_objs top_obj offtab_offset].zip(
  				trailer[6..7].unpack('CC') +
  				trailer[8..-1].scan(/.{8}/m).map do |longlong|
  					longlong.unpack('NN').inject(0) { |a, b| a * (1 << 32) + b }
  				end).flatten]

  		unless @trailer.num_objs * @trailer.int_size +
  					 @trailer.offtab_offset + 32 == @data.length
  			raise "problem parsing bplist"
  		end

      # Modified aquasyncs code to provide handling of 1byte offset table sizes, which does exist. - mosen
      bitsize_to_unpack = {1 => 'C', 2 => 'n'}
      
      @unpack_offset_char = bitsize_to_unpack[@trailer.int_size] or
        raise "unhandled int_size: #{@trailer.int_size}"
      
      # Modified aquasyncs code to handle differring offset size and object reference size which were originally assumed to be equal. - mosen
      @unpack_ref_char = bitsize_to_unpack[@trailer.ref_size] or
        raise "unhandled ref_size: #{@trailer.ref_size}"
      
  		@offtab = @data[@trailer.offtab_offset, @trailer.num_objs * @trailer.int_size].
  			unpack @unpack_offset_char * @trailer.num_objs
  	end

  	def load_object scanner

  		# arg can be an index (into offtab), or a string scanner
  		unless scanner.respond_to? :get_byte
  			@idx, scanner = scanner, StringScanner.new(@data)
  			#puts "Load object from offset table 0x%x" % @trailer.offtab_offset, "+#{@idx} -> %x" % offtab[@idx]
  			scanner.pos = offtab[@idx]
  		end

  		type = scanner.get_byte or raise "unexpected end of file"
  		aux = type[0] % 16
  		case type.unpack('B8')[0]
  		when '00000000'; nil
  		when '00001000'; false
  		when '00001001'; true
  		when '00001111'
  			# only expect this to happen if you just load sequential objects instead
  			# of using the offset table.
  			warn "got fill byte when using load_object"
  			# skip and try next one.
  			load_object scanner

  		#int	0001 nnnn	...		// # of bytes is 2^nnnn, big-endian bytes
  		when /^0001/
  			#puts "int"
  			x = 0
  			(1 << aux).times do
  				x *= 256
  				x += scanner.get_byte[0];
  			end
  			x
  			
    	#real	0010 nnnn	...		// # of bytes is 2^nnnn, big-endian bytes
	    when /^0010/
	      #puts "real"
	      x = 0
	      (1 << aux).times do
	        x *= 256
	        x += scanner.get_byte[0];
	      end
	       
    	#date	0011 0011	...		// 8 byte float follows, big-endian bytes
    	# Date stored as big endian double, regardless of host architecture
  	  when '00110011'
  	    #puts "date"
        d = @data[scanner.pos, 8]
        Time.utc(2001, 1, 1) + d.unpack('G')[0] # Apple uses Jan 1st 2001 as epoch(absolute) time
    	
    	#data	0100 nnnn	[int]	...	// nnnn is number of bytes unless 1111 then int count follows, followed by bytes
      when /^0100/
        n = aux == 15 ? load_object(scanner) : aux
        @data[scanner.pos, n] # return binary data TODO: consider StringIO

  		#string	0101 nnnn	[int]	...	// ASCII string, nnnn is # of chars, else 1111 then int count, then bytes
  		when /^0101/
  			n = aux == 15 ? load_object(scanner) : aux
  			@data[scanner.pos, n]

  		#string	0110 nnnn	[int]	...	// Unicode string, nnnn is # of chars, else 1111 then int count, then big-endian 2-byte uint16_t
      when /^0110/
        #puts 'utf8string'
        n = aux == 15 ? load_object(scanner) : aux
        @data[scanner.pos, n*2]

  		#array	1010 nnnn	[int]	objref*	// nnnn is count, unless '1111', then int count follows
  		when /^1010/
  			n = aux == 15 ? load_object(scanner) : aux
  			# mosen - added @trailer.ref_size * n instead of literal "2" - because the reference size can be anything according to the file spec
  			idxs = @data[scanner.pos, @trailer.ref_size * n].unpack(@unpack_ref_char + '*') # List of objects in the offset table that are a part of this structure
  			#p idxs
  			idxs.map { |idx| load_object idx }

  		#dict	1101 nnnn	[int]	keyref* objref*	// nnnn is count, unless '1111', then int count follows
  		when /^1101/
  			n = aux == 15 ? load_object(scanner) : aux
  			idxs = @data[scanner.pos, 2 * n].unpack(@unpack_ref_char + '*') # 
  			idxs = idxs[0 ... idxs.length / 2].zip(idxs[idxs.length / 2 .. -1]).flatten
  			Hash[*idxs.map { |idx| load_object idx }]

  		else
  			raise "unknown object type #{type.unpack('B8').inspect}"
  		end
  	end

  	def self.load data
  		BPlist.new(data).load_object 0
  	end
  end
end