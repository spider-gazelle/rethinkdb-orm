require "random"
require "time"

class RethinkORM::IdGenerator
  BASE_65 = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
             'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
             'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
             '-', '_', '~']
  TIME_OFFSET = 1388534400_i64 # Time.utc(2014, 1, 1).to_unix

  # Generate a time-sortable and unique (with high probability) primary key
  def self.next(table_name)
    time = Time.now
    timestamp = (time.to_unix - TIME_OFFSET) * 1_000_000 + time.to_unix_ms

    # Random tail renders it improbable that there will ever be an ID clash amongst nodes
    random_tail = (Random.rand(99999) + 1).to_s.rjust(5, '0')
    postfix = base_encode("#{timestamp}#{random_tail}", BASE_65)

    "#{table_name}-#{postfix}"
  end

  # Converts a string of base10 digits to string in arbitrary base
  def self.base_encode(number, base)
    base_size = base.size

    if number.is_a?(String)
      number = number.chars.reduce(0) { |acc, digit| acc * 10 + digit.to_i }
    end

    converted = [] of Char
    until number.zero?
      number, digit = number.divmod(base_size)
      converted.push(base[digit])
    end

    converted << base[0] if converted.empty?
    converted.reverse.join
  end
end
