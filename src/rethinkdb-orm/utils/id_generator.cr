require "random"
require "time"

# Generates time-sortable, collision resistant primary keys.
#
# Provides suitable performance with local, high-frequency batch insertions and
# distributed operation will low collision probability. Generated ID's are in
# the form `<prefix>-<postfix>` where prefix defaults to the table name and
# postfix is a lexicographically sortable 10 character unique identifier.
class RethinkORM::IdGenerator
  ENCODING = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    '-', '_', '~',
  }

  # Coverage to 2050 in 30 bits
  TIME_OFFSET = Time.utc(2014, 1, 1).to_unix

  # 30-bits of entropy
  RAND_LEN = 30
  RAND_GEN = seq max: 2_u32**RAND_LEN

  # Provides a pseudo-random sequence of non-repeating positive integers.
  #
  # Internally this implements a maximal linear feedback shift register via
  # Xorshift. For non-zero seeds this provides a cycle length of `2**32 - 1`.
  private class LSFR
    include Iterator(UInt32)

    def initialize(@seed : UInt32)
      @state = @seed
    end

    def next
      @state ^= @state << 13
      @state ^= @state >> 17
      @state ^= @state << 5
      if @state == @seed
        stop
      else
        @state
      end
    end
  end

  # Provides a channel with an infinite stream of psuedo-random values up to
  # *max* size and a guaranteed cycle of at least *max* samples.
  private def self.seq(max = UInt32::MAX, r = Random::DEFAULT)
    ch = Channel(UInt32).new
    spawn do
      loop do
        mask = Random::Secure.rand max
        lfsr = LSFR.new(r.rand UInt32)
        lfsr.select(&.< max).each do |count|
          ch.send count ^ mask
        end
      end
    end
    ch
  end

  def self.next(model)
    "#{model.table_name}-#{postfix}"
  end

  def self.next(table_name : String)
    "#{table_name}-#{postfix}"
  end

  def self.postfix
    String.build do |io|
      time = Time.utc.to_unix - TIME_OFFSET
      rand = RAND_GEN.receive
      (time << RAND_LEN | rand).digits(ENCODING.size).reverse_each do |ord|
        io << ENCODING[ord]
      end
    end
  end
end
