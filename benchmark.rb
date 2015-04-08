require 'benchmark'
require_relative 'lib/message_format'

iterations = 100_000

Benchmark.bm do |bm|
  bm.report('parse simple message') do
    parser = MessageFormat::Parser.new()
    iterations.times do
      parser.parse("I'm a super simple message")
    end
  end

  bm.report('format simple message') do
    message = MessageFormat.new("I'm a super simple message")
    iterations.times do
      message.format()
    end
  end

  bm.report('parse one arg message') do
    parser = MessageFormat::Parser.new()
    iterations.times do
      parser.parse("I'm a { arg } message")
    end
  end

  bm.report('format one arg message') do
    message = MessageFormat.new("I'm a { arg } message")
    iterations.times do
      message.format({ :arg => 'awesome' })
    end
  end

  bm.report('parse complex message') do
    parser = MessageFormat::Parser.new()
    iterations.times do
      parser.parse('On {day, date, short} {
  count, plural, offset:1
     =0 {nobody carpooled.}
     =1 {{driverName} drove {
      driverGender, select,
        male {himself}
      female {herself}
       other {themself}
    }.}
  other {{driverName} drove # people.}
}')
    end
  end

  bm.report('format complex message') do
    message = MessageFormat.new('On {day, date, short} {
  count, plural, offset:1
     =0 {nobody carpooled.}
     =1 {{driverName} drove {
      driverGender, select,
        male {himself}
      female {herself}
       other {themself}
    }.}
  other {{driverName} drove # people.}
}')
    iterations.times do
      message.format({
  :day => DateTime.now,
  :count => 5,
  :driverName => 'Jeremy',
  :driverGender => 'male'
})
    end
  end
end
