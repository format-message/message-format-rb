require 'twitter_cldr'
require_relative 'message_format/version'
require_relative 'message_format/parser'
require_relative 'message_format/interpreter'

module MessageFormat
  class MessageFormat

    def initialize ( pattern, locale=nil, raise_on_missing_params: false )
      @locale = (locale || TwitterCldr.locale).to_sym
      @format = Interpreter.interpret(
        Parser.parse(pattern),
        { 
          :locale => @locale,
          :raise_on_missing_params => raise_on_missing_params,
        },
      )
    end

    def format ( args=nil )
      @format.call(args)
    end

  end

  class << self

    def new ( pattern, locale=nil, raise_on_missing_params: false )
      MessageFormat.new(pattern, locale, raise_on_missing_params)
    end

    def format_message ( pattern, args=nil, locale=nil, raise_on_missing_params: false )
      locale ||= TwitterCldr.locale
      Interpreter.interpret(
        Parser.parse(pattern),
        { 
          :locale => locale.to_sym,
          :raise_on_missing_params => raise_on_missing_params,
        }
      ).call(args)
    end

  end
end
