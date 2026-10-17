module Crawling
  # 64-bit SimHash over word 3-shingles; near-duplicate pages differ in few bits.
  module Simhash
    BITS = 64
    SHINGLE = 3

    module_function

    def compute(words)
      return nil if words.empty?

      features = words.size < SHINGLE ? [ words.join(" ") ] : words.each_cons(SHINGLE).map { _1.join(" ") }
      vector = Array.new(BITS, 0)
      features.each do |feature|
        hash = Digest::SHA1.digest(feature).unpack1("Q>")
        BITS.times { |bit| vector[bit] += hash[bit] == 1 ? 1 : -1 }
      end
      value = vector.each_with_index.sum { |weight, bit| weight.positive? ? (1 << bit) : 0 }
      to_signed(value)
    end

    def distance(a, b)
      ((a ^ b) & ((1 << BITS) - 1)).to_s(2).count("1")
    end

    # Postgres bigint is signed.
    def to_signed(value) = value >= (1 << 63) ? value - (1 << 64) : value
  end
end
