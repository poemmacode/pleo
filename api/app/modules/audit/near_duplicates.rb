module Audit
  # Groups pages whose SimHash differs in at most MAX_DISTANCE bits. With 4 bands of 16 bits, two
  # hashes within distance 3 must share at least one band exactly (pigeonhole), so only pages in
  # the same band bucket are compared.
  module NearDuplicates
    MAX_DISTANCE = 3
    BANDS = 4
    BAND_BITS = 16

    module_function

    # pages: [[id, simhash], ...]. Returns arrays of ids, each with 2+ near-identical pages.
    def groups(pages)
      parent = pages.to_h { |id, _| [ id, id ] }
      find = ->(x) { parent[x] == x ? x : (parent[x] = find.(parent[x])) }

      BANDS.times do |band|
        buckets = Hash.new { |h, k| h[k] = [] }
        pages.each { |id, hash| buckets[(hash >> (band * BAND_BITS)) & 0xffff] << [ id, hash ] }
        buckets.each_value do |bucket|
          next if bucket.size < 2

          bucket.combination(2) do |(a, ha), (b, hb)|
            next unless Crawling::Simhash.distance(ha, hb) <= MAX_DISTANCE

            ra = find.(a)
            rb = find.(b)
            parent[ra] = rb unless ra == rb
          end
        end
      end

      pages.group_by { |id, _| find.(id) }.values.select { _1.size > 1 }.map { |group| group.map(&:first).sort }
    end
  end
end
