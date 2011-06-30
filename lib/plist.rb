#!/usr/bin/env ruby
#
# = plist
#
# This is the main file for plist. Everything interesting happens in
# Plist and Plist::Emit.
#
# Copyright 2006-2010 Ben Bleything and Patrick May
# Distributed under the MIT License
# Binary Plist parser added from aquasync's plist-read-only source by mosen.
#

require 'base64'
require 'cgi'
require 'stringio'

require 'plist/generator'
require 'plist/parser_xml'
require 'plist/parser_bplist'
require 'plist/parser'


module Plist
  VERSION = '3.1.0.1'
end
