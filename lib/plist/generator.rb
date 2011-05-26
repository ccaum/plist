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
  ARRAY = 'array'.freeze
  ARRAY_EMPTY = '<array/>'.freeze
  DATA_START = "\n<data>\n".freeze
  DATA_END = "\n</data>".freeze
  DATE = 'date'.freeze
  DICT = 'dict'.freeze
  DICT_EMPTY = '<dict/>'.freeze
  FALSE = '<false/>'.freeze
  INTEGER = 'integer'.freeze
  KEY = 'key'.freeze
  REAL = 'real'.freeze
  STRING = 'string'.freeze
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
    output = plist_node(obj)

    output = wrap(output) if envelope

    output
  end

  # Writes the serialized object's plist to the specified filename.
  def self.save_plist(obj, filename)
    File.open(filename, 'wb') do |f|
      f.write(obj.to_plist)
    end
  end

  private
  def self.plist_node(element)
    output = []

    if element.respond_to? :to_plist_node
      output << element.to_plist_node
    else
      case element
      when Array
        if element.empty?
          output << ARRAY_EMPTY
        else
          output << tag(ARRAY) {
            element.collect {|e| plist_node(e)}
          }
        end
      when Hash
        if element.empty?
          output << DICT_EMPTY
        else
          inner_tags = []

          element.keys.sort.each do |k|
            v = element[k]
            inner_tags << tag(KEY, CGI::escapeHTML(k.to_s))
            inner_tags << plist_node(v)
          end

          output << tag(DICT) {
            inner_tags
          }
        end
      when true
        output << TRUE
      when false
        output << FALSE
      when Time
        output << tag(DATE, element.utc.strftime(TIME_FORMAT))
      when Date # also catches DateTime
        output << tag(DATE, element.strftime(TIME_FORMAT))
      when String, Symbol, Fixnum, Bignum, Integer, Float
        output << tag(element_type(element), CGI::escapeHTML(element.to_s))
      when IO, StringIO
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
      else
        output << comment( 'The <data> element below contains a Ruby object which has been serialized with Marshal.dump.' )
        data = "\n"
        Base64::encode64(Marshal.dump(element)).gsub(/\s+/, '').scan(/.{1,68}/o) { data << $& << "\n" }
        output << tag('data', data )
      end
    end

    output.join
  end

  def self.comment(content)
    "<!-- #{content} -->\n"
  end

  def self.tag(type, contents = '', &block)
    contents = block.call if block_given?
    "<#{type}>#{contents.to_s}</#{type}>"
  end

  def self.wrap(contents)
<<-eos
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">#{contents}</plist>
eos
  end

  def self.element_type(item)
    case item
    when String, Symbol
      STRING
    when Fixnum, Bignum, Integer
      INTEGER
    when Float
      REAL
    else
      raise "Don't know about this data type... something must be wrong!"
    end
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
