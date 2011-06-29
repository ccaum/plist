#!/usr/bin/env ruby
#
# = plist
#
# Copyright 2011 mosen
# Distributed under the MIT License
#

module Plist
  require 'plist/parser_xml.rb'
  require 'plist/parser_bplist.rb'
  
  def Plist::parse( plist_data_or_file )

    if plist_data_or_file.respond_to? :read
      data = plist_data_or_file.read
    elsif File.exists? plist_data_or_file
      data = File.read( plist_data_or_file )
    else
      data = plist_data_or_file
    end

    #puts "Magic number: ", data[0..5]
    data[0..5] == 'bplist' ? Plist::parse_bplist( data ) : Plist::parse_xml( data )
  end
  
end