# frozen_string_literal: true
#
# Parser
#
# Turns this:
#  `You have { numBananas, plural,
#       =0 {no bananas}
#      one {a banana}
#    other {# bananas}
#  } for sale`
#
# into this:
#  [ "You have ", [ "numBananas", "plural", 0, {
#       "=0": [ "no bananas" ],
#      "one": [ "a banana" ],
#    "other": [ [ '#' ], " bananas" ]
#  } ], " for sale." ]
#
module MessageFormat
  class Parser

    def initialize ()
      @pattern = nil
      @length = 0
      @index = 0
    end

    def parse ( pattern )
      if !pattern.is_a?(String)
        raise_expected('String pattern', pattern.class.to_s)
      end

      @pattern = pattern
      @length = pattern.length
      @index = 0
      parse_message("message")
    end

    def is_digit ( char )
      char == '0' or
      char == '1' or
      char == '2' or
      char == '3' or
      char == '4' or
      char == '5' or
      char == '6' or
      char == '7' or
      char == '8' or
      char == '9'
    end

    def is_whitespace ( char )
      char == "\s" or
      char == "\t" or
      char == "\n" or
      char == "\r" or
      char == "\f" or
      char == "\v" or
      char == "\u00A0" or
      char == "\u2028" or
      char == "\u2029"
    end

    def skip_whitespace ()
      while @index < @length and is_whitespace(@pattern[@index])
        @index += 1
      end
    end

    def parse_text ( parent_type )
      is_hash_special = (parent_type == 'plural' or parent_type == 'selectordinal')
      is_arg_style = (parent_type == 'style')
      text = +''
      while @index < @length
        char = @pattern[@index]
        if (
          char == '{' or
          char == '}' or
          (is_hash_special and char == '#') or
          (is_arg_style and is_whitespace(char))
        )
          break
        elsif char == '\''
          @index += 1
          char = @pattern[@index]
          if char == '\'' # double is always 1 '
            text << char
            @index += 1
          elsif (
            # only when necessary
            char == '{' or
            char == '}' or
            (is_hash_special and char == '#') or
            (is_arg_style and is_whitespace(char))
          )
            text << char
            found_closing_quote = false
            while @index + 1 < @length
              @index += 1
              char = @pattern[@index]
              if @pattern.slice(@index, 2) == '\'\'' # double is always 1 '
                text << char
                @index += 1
              elsif char == '\'' # end of quoted
                @index += 1
                found_closing_quote = true
                break
              else
                text << char
              end
            end
            # If no closing quote was found, increment past the last character
            # to avoid reprocessing it in the outer loop
            if !found_closing_quote
              @index += 1
            end
          else # lone ' is just a '
            text << '\''
            # already incremented
          end
        else
          text << char
          @index += 1
        end
      end

      text
    end

    def parse_argument ()
      if @pattern[@index] == '#'
        @index += 1 # move passed #
        return [ '#' ]
      end

      @index += 1 # move passed {
      id = parse_arg_id()
      char = @pattern[@index]
      if char == '}' # end argument
        @index += 1 # move passed }
        return [ id ]
      end
      if char != ','
        raise_expected(',')
      end
      @index += 1 # move passed ,

      type = parse_arg_type()
      char = @pattern[@index]
      if char == '}' # end argument
        if (
          type == 'plural' or
          type == 'selectordinal' or
          type == 'select'
        )
          raise_expected(type + ' message options')
        end
        @index += 1 # move passed }
        return [ id, type ]
      end
      if char != ','
        raise_expected(',')
      end
      @index += 1 # move passed ,

      format = nil
      offset = nil
      if type == 'plural' or type == 'selectordinal'
        offset = parse_plural_offset()
        format = parse_sub_messages(type)
      elsif type == 'select'
        format = parse_sub_messages(type)
      else
        format = parse_simple_format()
      end
      char = @pattern[@index]
      if char != '}' # not ended argument
        raise_expected('}')
      end
      @index += 1 # move passed

      (type == 'plural' or type == 'selectordinal') ?
        [ id, type, offset, format ] :
        [ id, type, format ]
    end

    def parse_arg_id ()
      skip_whitespace()
      id = +''
      while @index < @length
        char = @pattern[@index]
        if char == '{' or char == '#'
          raise_expected('argument id')
        end
        if char == '}' or char == ',' or is_whitespace(char)
          break
        end
        id << char
        @index += 1
      end
      if id.empty?
        raise_expected('argument id')
      end
      skip_whitespace()
      id
    end

    def parse_arg_type ()
      skip_whitespace()
      arg_type = nil
      types = [
        'number', 'date', 'time', 'ordinal', 'duration', 'spellout', 'plural', 'selectordinal', 'select'
      ]
      types.each do |type|
        if @pattern.slice(@index, type.length) == type
          arg_type = type
          @index += type.length
          break
        end
      end
      if !arg_type
        raise_expected(types.join(', '))
      end
      skip_whitespace()
      arg_type
    end

    def parse_simple_format ()
      skip_whitespace()
      style = parse_text('style')
      if style.empty?
        raise_expected('argument style name')
      end
      skip_whitespace()
      style
    end

    def parse_plural_offset ()
      skip_whitespace()
      offset = 0
      if @pattern.slice(@index, 7) == 'offset:'
        @index += 7 # move passed offset:
        skip_whitespace()
        start = @index
        while (
          @index < @length and
          is_digit(@pattern[@index])
        )
          @index += 1
        end
        if start == @index
          raise_expected('offset number')
        end
        offset = @pattern[start..@index].to_i
        skip_whitespace()
      end
      offset
    end

    def parse_sub_messages ( parent_type )
      skip_whitespace()
      options = {}
      has_subs = false
      while (
        @index < @length and
        @pattern[@index] != '}'
      )
        selector = parse_selector()
        skip_whitespace()
        options[selector] = parse_sub_message(parent_type)
        has_subs = true
        skip_whitespace()
      end
      if !has_subs
        raise_expected(parent_type + ' message options')
      end
      if !options.has_key?('other') # does not have an other selector
        raise_expected(nil, nil, '"other" option must be specified in ' + parent_type)
      end
      options
    end

    def parse_selector ()
      selector = +''
      while @index < @length
        char = @pattern[@index]
        if char == '}' or char == ','
          raise_expected('{')
        end
        if char == '{' or is_whitespace(char)
          break
        end
        selector << char
        @index += 1
      end
      if selector.empty?
        raise_expected('selector')
      end
      skip_whitespace()
      selector
    end

    def parse_sub_message ( parent_type )
      char = @pattern[@index]
      if char != '{'
        raise_expected('{')
      end
      @index += 1 # move passed {
      message = parse_message(parent_type)
      char = @pattern[@index]
      if char != '}'
        raise_expected('}')
      end
      @index += 1 # move passed }
      message
    end

    def parse_message ( parent_type )
      elements = []
      text = parse_text(parent_type)
      if !text.empty?
        elements.push(text)
      end
      while @index < @length
        if @pattern[@index] == '}'
          if parent_type == 'message'
            raise_expected()
          end
          break
        end
        elements.push(parse_argument())
        text = parse_text(parent_type)
        if !text.empty?
          elements.push(text)
        end
      end
      elements
    end

    def raise_expected ( expected=nil, found=nil, message=nil )
      lines = @pattern[0..@index].split(/\r?\n/)
      line = lines.length
      column = lines.last.length
      if !found
        found = @index < @length ? @pattern[@index] : 'end of input'
      end
      if !message
        message = error_message(expected, found)
      end
      message += ' in "' + @pattern.gsub(/\r?\n/, "\n") + '"'

      raise SyntaxError.new(message, expected, found, @index, line, column)
    end

    def error_message ( expected=nil, found )
      expected ?
        "Expected \"#{ expected }\" but found \"#{ found }\"" :
        "Unexpected \"#{ found }\" found" 
    end

    def self.parse ( pattern )
      Parser.new().parse(pattern)
    end

    #
    # Syntax Error
    #  Holds information about bad syntax found in a message pattern
    #
    class SyntaxError < StandardError

      attr_reader :expected
      attr_reader :found
      attr_reader :offset
      attr_reader :line
      attr_reader :column

      def initialize (message, expected, found, offset, line, column)
        super(message)
        @expected = expected
        @found = found
        @offset = offset
        @line = line
        @column = column
      end

    end

  end
end
