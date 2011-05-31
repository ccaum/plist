#!/usr/bin/env ruby
#
# = plist
#
# Copyright 2006-2010 Ben Bleything and Patrick May
# Distributed under the MIT License
#

module Plist ; end

# === Create a plist
# You can dump an object to a plist in one of two ways:
#
# * <tt>Plist::Emit.dump(obj)</tt>
# * <tt>obj.to_plist</tt>
#   * This requires that you mixin the <tt>Plist::Emit</tt> module, which is already done for +Array+ and +Hash+.
#
# The following Ruby classes are converted into native plist types:
#   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time, true, false
# * +Array+ and +Hash+ are both recursive; their elements will be converted into plist nodes inside the <array> and <dict> containers (respectively).
# * +IO+ (and its descendants) and +StringIO+ objects are read from and their contents placed in a <data> element.
# * User classes may implement +to_plist_node+ to dictate how they should be serialized; otherwise the object will be passed to <tt>Marshal.dump</tt> and the result placed in a <data> element.
#
# For detailed usage instructions, refer to USAGE[link:files/docs/USAGE.html] and the methods documented below.
module Plist::Emit
  ARRAY_CLOSE = '</array>'.freeze
  ARRAY_EMPTY = '<array/>'.freeze
  ARRAY_OPEN = '<array>'.freeze
  DATA_START = "\n<data>\n".freeze
  DATA_END = "\n</data>".freeze
  DICT_OPEN = '<dict>'.freeze
  DICT_CLOSE = '</dict>'.freeze
  DICT_EMPTY = '<dict/>'.freeze
  FALSE = '<false/>'.freeze
  TIME_FORMAT = '%Y-%m-%dT%H:%M:%SZ'.freeze
  TRUE = '<true/>'.freeze

  # Helper method for injecting into classes.  Calls <tt>Plist::Emit.dump</tt> with +self+.
  def to_plist(envelope = true)
    Plist::Emit.dump(self, envelope)
  end

  # Helper method for injecting into classes.  Calls <tt>Plist::Emit.save_plist</tt> with +self+.
  def save_plist(filename)
    Plist::Emit.save_plist(self, filename)
  end

  # The following Ruby classes are converted into native plist types:
  #   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time
  #
  # Write us (via RubyForge) if you think another class can be coerced safely into one of the expected plist classes.
  #
  # +IO+ and +StringIO+ objects are encoded and placed in <data> elements; other objects are <tt>Marshal.dump</tt>'ed unless they implement +to_plist_node+.
  #
  # The +envelope+ parameters dictates whether or not the resultant plist fragment is wrapped in the normal XML/plist header and footer.  Set it to false if you only want the fragment.
  def self.dump(obj, envelope = true)
    output = plist_node(obj, []).join
    envelope ? wrap(output) : output
  end

  # Writes the serialized object's plist to the specified filename.
  def self.save_plist(obj, filename)
    File.open(filename, 'wb') do |f|
      f.write(obj.to_plist)
    end
  end

  private
  def self.plist_node(element, output)
    if element.is_a?(String)
      output << "<string>#{CGI.escapeHTML(element)}</string>"
    elsif element.is_a?(Hash)
      if element.empty?
        output << DICT_EMPTY
      else
        output << DICT_OPEN

        element.each_pair do |k, v|
          output << "<key>#{CGI.escapeHTML(k.to_s)}</key>"
          plist_node(v, output)
        end

        output << DICT_CLOSE
      end
    elsif element.is_a?(Array)
      if element.empty?
        output << ARRAY_EMPTY
      else
        output << ARRAY_OPEN
        element.each {|e| plist_node(e, output)}
        output << ARRAY_CLOSE
      end
    elsif element.is_a?(TrueClass)
      output << TRUE
    elsif element.is_a?(FalseClass)
      output << FALSE
    elsif element.is_a?(Time)
      output << "<date>#{element.utc.strftime(TIME_FORMAT)}</date>"
    elsif element.is_a?(Date) # also catches DateTime
      output << "<date>#{element.strftime(TIME_FORMAT)}</date>"
    elsif element.is_a?(Symbol)
      output << "<string>#{CGI::escapeHTML(element.to_s)}</string>"
    elsif element.is_a?(Float)
      output << "<real>#{element}</real>"
    elsif element.is_a?(Numeric)
      output << "<integer>#{element}</integer>"
    elsif element.is_a?(IO) || element.is_a?(StringIO)
      element.rewind
      contents = element.read

      # note that apple plists are wrapped at a different length then
      # what ruby's base64 wraps by default.
      # I used #encode64 instead of #b64encode (which allows a length arg)
      # because b64encode is b0rked and ignores the length arg.
      output << DATA_START

      data = []
      Base64::encode64(contents).gsub(/\s+/, '').scan(/.{1,68}/o) { data << $& }
      output << data.join("\n")

      output << DATA_END
    elsif element.respond_to? :to_plist_node
      output << element.to_plist_node
    else
      output << comment('The <data> element below contains a Ruby object which has been serialized with Marshal.dump.')
      data = "\n"
      Base64::encode64(Marshal.dump(element)).gsub(/\s+/, '').scan(/.{1,68}/o) { data << $& << "\n" }
      output << "<data>#{data}</data>"
    end

    output
  end

  def self.comment(content)
    "<!-- #{content} -->\n"
  end

  def self.wrap(contents)
<<-eos
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">#{contents}</plist>
eos
  end
end

# we need to add this so sorting hash keys works properly
class Symbol #:nodoc:
  def <=> (other)
    self.to_s <=> other.to_s
  end
end

class Array #:nodoc:
  include Plist::Emit
end

class Hash #:nodoc:
  include Plist::Emit
end
