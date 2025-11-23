require 'spec_helper'

describe MessageFormat do
  describe '.new' do
    it 'throws an error on bad syntax' do
      expect { MessageFormat.new({}) }.to raise_error
      expect { MessageFormat.new('no finish arg {') }.to raise_error
      expect { MessageFormat.new('no start arg }') }.to raise_error
      expect { MessageFormat.new('empty arg {}') }.to raise_error
      expect { MessageFormat.new('unfinished select { a, select }') }.to raise_error
      expect { MessageFormat.new('unfinished select { a, select, }') }.to raise_error
      expect { MessageFormat.new('sub with no selector { a, select, {hi} }') }.to raise_error
      expect { MessageFormat.new('sub with no other { a, select, foo {hi} }') }.to raise_error
      expect { MessageFormat.new('wrong escape \\{') }.to raise_error
      expect { MessageFormat.new('wrong escape \'{\'', 'en', { escape: '\\' }) }.to raise_error
      expect { MessageFormat.new('bad arg type { a, bogus, nope }') }.to raise_error
      expect { MessageFormat.new('bad arg separator { a bogus, nope }') }.to raise_error
    end
  end

  describe '#format' do
    it 'formats a simple message' do
      pattern = 'Simple string with nothing special'
      message = MessageFormat.new(pattern, 'en-US').format()

      expect(message).to eql('Simple string with nothing special')
    end

    it 'handles pattern with escaped text' do
      pattern = 'This isn\'\'t a \'{\'\'simple\'\'}\' \'string\''
      message = MessageFormat.new(pattern, 'en-US').format()

      expect(message).to eql('This isn\'t a {\'simple\'} \'string\'')
    end

    it 'handles escaped single apostrophe escapes' do
      pattern = 'Hello \'{literal}!'
      message = MessageFormat.new(pattern, 'en-US').format()

      expect(message).to eql('Hello {literal}!')
    end

    it 'accepts arguments' do
      pattern = 'x{ arg }z'
      message = MessageFormat.new(pattern, 'en-US').format({ :arg => 'y' })

      expect(message).to eql('xyz')
    end

    it 'formats numbers, dates, and times' do
      pattern = '{ n, number } : { d, date, short } { d, time, short }'
      message = MessageFormat.new(pattern, 'en-US').format({ :n => 0, :d => DateTime.new(0) })

      expect(message).to match(/^0 \: \d\d?\/\d\d?\/\d{2,4} \d\d?\:\d\d [AP]M$/)
    end

    it 'formats integer number' do
      pattern = '{ n, number, integer }'
      message = MessageFormat.new(pattern, 'en-US').format({ n: 1234 })

      expect(message).to match('1,234')
    end

    it 'handles plurals' do
      pattern =
        'On {takenDate, date, short} {name} {numPeople, plural, offset:1
            =0 {didn\'t carpool.}
            =1 {drove himself.}
         other {drove # people.}}'
      message = MessageFormat.new(pattern, 'en-US')
          .format({ :takenDate => DateTime.now, :name => 'Bob', :numPeople => 5 })

      expect(message).to match(/^On \d\d?\/\d\d?\/\d{2,4} Bob drove 4 people.$/)
    end

    it 'handles plurals for other locales' do
      pattern =
        '{n, plural,
          zero {zero}
           one {one}
           two {two}
           few {few}
          many {many}
         other {other}}'
      message = MessageFormat.new(pattern, 'ar')

      expect(message.format({ n: 0 })).to eql('zero')
      expect(message.format({ n: 1 })).to eql('one')
      expect(message.format({ n: 2 })).to eql('two')
      expect(message.format({ n: 3 })).to eql('few')
      expect(message.format({ n: 11 })).to eql('many')
    end

    it 'handles selectordinals' do
      pattern =
        '{n, selectordinal,
           one {#st}
           two {#nd}
           few {#rd}
         other {#th}}'
      message = MessageFormat.new(pattern, 'en')

      expect(message.format({ n: 1 })).to eql('1st')
      expect(message.format({ n: 22 })).to eql('22nd')
      expect(message.format({ n: 103 })).to eql('103rd')
      expect(message.format({ n: 4 })).to eql('4th')
    end

    it 'handles select' do
      pattern =
        '{ gender, select,
           male {it\'s his turn}
         female {it\'s her turn}
          other {it\'s their turn}}'
      message = MessageFormat.new(pattern, 'en-US')
          .format({ gender: 'female' })

      expect(message).to eql('it\'s her turn')
    end

    it 'should throw an error when args are expected and not passed' do
      expect { MessageFormat.new('{a}').format() }.to raise_error
    end
  end

  describe '.formatMessage' do
    it 'formats messages' do
      pattern =
        'On {takenDate, date, short} {name} {numPeople, plural, offset:1
            =0 {didn\'t carpool.}
            =1 {drove himself.}
         other {drove # people.}}'
      message = MessageFormat.format_message(pattern,
        :takenDate => DateTime.now,
        :name => 'Bob',
        :numPeople => 5
      )
      expect(message).to match(/^On \d\d?\/\d\d?\/\d{2,4} Bob drove 4 people.$/)

      message = MessageFormat::format_message(pattern,
        :takenDate => DateTime.now,
        :name => 'Bill',
        :numPeople => 6
      )
      expect(message).to match(/^On \d\d?\/\d\d?\/\d{2,4} Bill drove 5 people.$/)
    end
  end

  describe 'locales' do
    it 'doesn\'t throw for any locale\'s plural function' do
      pattern =
        '{n, plural,
          zero {zero}
           one {one}
           two {two}
           few {few}
          many {many}
         other {other}}'
      TwitterCldr.supported_locales.each do |locale|
        message = MessageFormat.new(pattern, locale)
        for n in 0..200 do
          result = message.format({ :n => n })
          expect(result).to match(/^(zero|one|two|few|many|other)$/)
        end
      end
    end
  end
end
