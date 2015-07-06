# MessageFormat

Parse and format i18n messages using ICU MessageFormat patterns

## Installation

Add this line to your application's Gemfile:

    gem 'message_format'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install message_format

## Usage

```ruby
require 'message_format'

message = MessageFormat.new('Hello { place }!', 'en-US')
formatted = message.format({ :place => 'World' })
```

The [ICU Message Format][icu-message] is a great format for user-visible strings, and includes simple placeholders, number and date placeholders, and selecting among submessages for gender and plural arguments. The format is used in apis in [C++][icu-cpp], [PHP][icu-php], [Java][icu-java], and [JavaScript][icu-javascript].

## Contributing

1. Fork it ( https://github.com/format-message/message-format-rb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

This software is free to use under the MIT license. See the [LICENSE.txt file][LICENSE] for license text and copyright information.

[icu-message]: http://userguide.icu-project.org/formatparse/messages
[icu-cpp]: http://icu-project.org/apiref/icu4c/classicu_1_1MessageFormat.html
[icu-php]: http://php.net/manual/en/class.messageformatter.php
[icu-java]: http://icu-project.org/apiref/icu4j/
[icu-javascript]: https://github.com/format-message/message-format
[LICENSE]: https://github.com/format-message/message-format-rb/blob/master/LICENSE.txt
