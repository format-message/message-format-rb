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
        throwExpected('String pattern', pattern.class.to_s)
      end

      @pattern = pattern
      @length = pattern.length
      @index = 0
      return parseMessage("message")
    end

    def isDigit ( char )
      return (
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
      )
    end

    def isWhitespace ( char )
      return (
        char == "\s" or
        char == "\t" or
        char == "\n" or
        char == "\r" or
        char == "\f" or
        char == "\v" or
        char == "\u00A0" or
        char == "\u2028" or
        char == "\u2029"
      )
    end

    def skipWhitespace ()
      while @index < @length and isWhitespace(@pattern[@index])
        @index += 1
      end
    end

    def parseText ( parentType )
      isHashSpecial = (parentType == 'plural' or parentType == 'selectordinal')
      isArgStyle = (parentType == 'style')
      text = ''
      while @index < @length
        char = @pattern[@index]
        if (
          char == '{' or
          char == '}' or
          (isHashSpecial and char == '#') or
          (isArgStyle and isWhitespace(char))
        )
          break
        elsif char == '\''
          @index += 1
          char = @pattern[@index]
          if char == '\'' # double is always 1 '
            text += char
            @index += 1
          elsif (
            # only when necessary
            char == '{' or
            char == '}' or
            (isHashSpecial and char == '#') or
            (isArgStyle and isWhitespace(char))
          )
            text += char
            while @index + 1 < @length
              @index += 1
              char = @pattern[@index]
              if @pattern.slice(@index, 2) == '\'\'' # double is always 1 '
                text += char
                @index += 1
              elsif char == '\'' # end of quoted
                @index += 1
                break
              else
                text += char
              end
            end
          else # lone ' is just a '
            text += '\''
            # already incremented
          end
        else
          text += char
          @index += 1
        end
      end

      return text
    end

    def parseArgument ()
      if @pattern[@index] == '#'
        @index += 1 # move passed #
        return [ '#' ]
      end

      @index += 1 # move passed {
      id = parseArgId()
      char = @pattern[@index]
      if char == '}' # end argument
        @index += 1 # move passed }
        return [ id ]
      end
      if char != ','
        throwExpected(',')
      end
      @index += 1 # move passed ,

      type = parseArgType()
      char = @pattern[@index]
      if char == '}' # end argument
        if (
          type == 'plural' or
          type == 'selectordinal' or
          type == 'select'
        )
          throwExpected(type + ' message options')
        end
        @index += 1 # move passed }
        return [ id, type ]
      end
      if char != ','
        throwExpected(',')
      end
      @index += 1 # move passed ,

      format = nil
      offset = nil
      if type == 'plural' or type == 'selectordinal'
        offset = parsePluralOffset()
        format = parseSubMessages(type)
      elsif type == 'select'
        format = parseSubMessages(type)
      else
        format = parseSimpleFormat()
      end
      char = @pattern[@index]
      if char != '}' # not ended argument
        throwExpected('}')
      end
      @index += 1 # move passed

      return (type == 'plural' or type == 'selectordinal') ?
        [ id, type, offset, format ] :
        [ id, type, format ]
    end

    def parseArgId ()
      skipWhitespace()
      id = ''
      while @index < @length
        char = @pattern[@index]
        if char == '{' or char == '#'
          throwExpected('argument id')
        end
        if char == '}' or char == ',' or isWhitespace(char)
          break
        end
        id += char
        @index += 1
      end
      if id.empty?
        throwExpected('argument id')
      end
      skipWhitespace()
      return id
    end

    def parseArgType ()
      skipWhitespace()
      argType = nil
      types = [
        'number', 'date', 'time', 'ordinal', 'duration', 'spellout', 'plural', 'selectordinal', 'select'
      ]
      types.each do |type|
        if @pattern.slice(@index, type.length) == type
          argType = type
          @index += type.length
          break
        end
      end
      if !argType
        throwExpected(types.join(', '))
      end
      skipWhitespace()
      return argType
    end

    def parseSimpleFormat ()
      skipWhitespace()
      style = parseText('style')
      if style.empty?
        throwExpected('argument style name')
      end
      skipWhitespace()
      return style
    end

    def parsePluralOffset ()
      skipWhitespace()
      offset = 0
      if @pattern.slice(@index, 7) == 'offset:'
        @index += 7 # move passed offset:
        skipWhitespace()
        start = @index
        while (
          @index < @length and
          isDigit(@pattern[@index])
        )
          @index += 1
        end
        if start == @index
          throwExpected('offset number')
        end
        offset = @pattern[start..@index].to_i
        skipWhitespace()
      end
      return offset
    end

    def parseSubMessages ( parentType )
      skipWhitespace()
      options = {}
      hasSubs = false
      while (
        @index < @length and
        @pattern[@index] != '}'
      )
        selector = parseSelector()
        skipWhitespace()
        options[selector] = parseSubMessage(parentType)
        hasSubs = true
        skipWhitespace()
      end
      if !hasSubs
        throwExpected(parentType + ' message options')
      end
      if !options.has_key?('other') # does not have an other selector
        throwExpected(nil, nil, '"other" option must be specified in ' + parentType)
      end
      return options
    end

    def parseSelector ()
      selector = ''
      while @index < @length
        char = @pattern[@index]
        if char == '}' or char == ','
          throwExpected('{')
        end
        if char == '{' or isWhitespace(char)
          break
        end
        selector += char
        @index += 1
      end
      if selector.empty?
        throwExpected('selector')
      end
      skipWhitespace()
      return selector
    end

    def parseSubMessage ( parentType )
      char = @pattern[@index]
      if char != '{'
        throwExpected('{')
      end
      @index += 1 # move passed {
      message = parseMessage(parentType)
      char = @pattern[@index]
      if char != '}'
        throwExpected('}')
      end
      @index += 1 # move passed }
      return message
    end

    def parseMessage ( parentType )
      elements = []
      text = parseText(parentType)
      if !text.empty?
        elements.push(text)
      end
      while @index < @length
        if @pattern[@index] == '}'
          if parentType == 'message'
            throwExpected()
          end
          break
        end
        elements.push(parseArgument())
        text = parseText(parentType)
        if !text.empty?
          elements.push(text)
        end
      end
      return elements
    end

    def throwExpected ( expected=nil, found=nil, message=nil )
      lines = @pattern[0..@index].split(/\r?\n/)
      line = lines.length
      column = lines.last.length
      if !found
        found = @index < @length ? @pattern[@index] : 'end of input'
      end
      if !message
        message = errorMessage(expected, found)
      end
      message += ' in "' + @pattern.gsub(/\r?\n/, "\n") + '"'

      raise SyntaxError.new(message, expected, found, @index, line, column)
    end

    def errorMessage ( expected=nil, found )
      if !expected
        return "Unexpected \"#{ found }\" found"
      end
      return "Expected \"#{ expected }\" but found \"#{ found }\""
    end

    def self.parse ( pattern )
      return Parser.new().parse(pattern)
    end

    #
    # Syntax Error
    #  Holds information about bad syntax found in a message pattern
    #
    class SyntaxError < StandardError

      attr_reader :message
      attr_reader :expected
      attr_reader :found
      attr_reader :offset
      attr_reader :line
      attr_reader :column

      def initialize (message, expected, found, offset, line, column)
        @message = message
        @expected = expected
        @found = found
        @offset = offset
        @line = line
        @column = column
      end

    end

  end
end
