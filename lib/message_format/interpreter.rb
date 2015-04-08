require 'twitter_cldr'

#
# Interpreter
#
# Turns this:
#  [ "You have ", [ "numBananas", "plural", 0, {
#       "=0": [ "no bananas" ],
#      "one": [ "a banana" ],
#    "other": [ [ '#' ], " bananas" ]
#  } ], " for sale." ]
#
# into this:
#  format({ numBananas:0 })
#  "You have no bananas for sale."
#
module MessageFormat
  class Interpreter

    def initialize ( options=nil )
      if options and options.has_key?(:locale)
        @locale = options[:locale]
      else
        @locale = TwitterCldr.locale
      end
    end

    def interpret ( elements )
      return interpret_subs(elements)
    end

    def interpret_subs ( elements, parent=nil )
      elements = elements.map do |element|
        interpret_element(element, parent)
      end

      # optimize common case
      if elements.length == 1
        return elements[0]
      end

      return lambda do |args|
        elements.map { |element| element.call(args) }.join ''
      end
    end

    def interpret_element ( element, parent=nil )
      if element.is_a?(String)
        return lambda { |args=nil| element }
      end

      id, type, style = element
      offset = 0

      if id == '#'
        id = parent[0]
        type = 'number'
        offset = parent[2] || 0
        style = nil
      end

      id = id.to_sym # actual arguments should always be keyed by symbols

      case type
        when 'number'
          return interpret_number(id, offset, style)
        when 'date', 'time'
          return interpret_date_time(id, type, style)
        when 'plural', 'selectordinal'
          offset = element[2]
          options = element[3]
          return interpret_plural(id, type, offset, options)
        when 'select'
          return interpret_select(id, style)
        when 'spellout', 'ordinal', 'duration'
          return interpret_number(id, offset, type)
        else
          return interpret_simple(id)
      end
    end

    def interpret_number ( id, offset, style )
      locale = @locale
      return lambda do |args|
        number = TwitterCldr::Localized::LocalizedNumber.new(args[id] - offset, locale)
        if style == 'integer'
          return number.to_decimal(:precision => 0).to_s
        elsif style == 'percent'
          return number.to_percent.to_s
        elsif style == 'currency'
          return number.to_currency.to_s
        elsif style == 'spellout'
          return number.spellout
        elsif style == 'ordinal'
          return number.to_rbnf_s('OrdinalRules', 'digits-ordinal')
        else
          return number.to_s
        end
      end
    end

    def interpret_date_time ( id, type, style='medium' )
      locale = @locale
      return lambda do |args|
        datetime = TwitterCldr::Localized::LocalizedDateTime.new(args[id], locale)
        datetime = type == 'date' ? datetime.to_date : datetime.to_time
        if style == 'medium'
          return datetime.to_medium_s
        elsif style == 'long'
          return datetime.to_long_s
        elsif style == 'short'
          return datetime.to_short_s
        elsif style == 'full'
          return datetime.to_full_s
        else
          return datetime.to_additional_s(style)
        end
      end
    end

    def interpret_plural ( id, type, offset, children )
      parent = [ id, type, offset ]
      options = {}
      children.each do |key, value|
        options[key.to_sym] = interpret_subs(value, parent)
      end

      locale = @locale
      plural_type = type == 'selectordinal' ? :ordinal : :cardinal
      return lambda do |args|
        arg = args[id]
        exactSelector = ('=' + arg.to_s).to_sym
        keywordSelector = TwitterCldr::Formatters::Plurals::Rules.rule_for(arg - offset, locale, plural_type)
        func =
          options[exactSelector] ||
          options[keywordSelector] ||
          options[:other]
        return func.call(args)
      end
    end

    def interpret_select ( id, children )
      options = {}
      children.each do |key, value|
        options[key.to_sym] = interpret_subs(value, nil)
      end
      return lambda do |args|
        selector = args[id].to_sym
        func =
          options[selector] ||
          options[:other]
        return func.call(args)
      end
    end

    def interpret_simple ( id )
      return lambda do |args|
        return args[id].to_s
      end
    end

    def self.interpret ( elements, options=nil )
      return Interpreter.new(options).interpret(elements)
    end

  end
end
