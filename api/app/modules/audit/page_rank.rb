module Audit
  # Internal PageRank over followed links between HTML pages (damping 0.85, 20 iterations).
  # Rank of pages without outgoing links is spread evenly so the total stays 1.
  module PageRank
    DAMPING = 0.85
    ITERATIONS = 20

    module_function

    def compute_for(crawl)
      ids = crawl.pages.where(status_code: 200, extracted: true).order(:id).pluck(:id)
      return if ids.empty?

      sources, targets = edges(crawl)
      ranks = compute(ids, sources, targets)
      Page.connection.exec_update(<<~SQL.squish, "Audit::PageRank", [ "{#{ids.join(",")}}", "{#{ranks.join(",")}}" ])
        UPDATE pages SET internal_pagerank = v.rank
        FROM (SELECT unnest($1::bigint[]) AS id, unnest($2::float8[]) AS rank) v
        WHERE pages.id = v.id
      SQL
    end

    # Edges come back as two Postgres arrays to avoid materialising millions of row objects.
    def edges(crawl)
      row = Page.connection.select_rows(<<~SQL.squish, "Audit::PageRank edges", [ crawl.id ]).first
        SELECT COALESCE(array_agg(from_page_id), '{}'), COALESCE(array_agg(to_page_id), '{}') FROM (
          SELECT DISTINCT from_page_id, to_page_id FROM links
          WHERE crawl_id = $1 AND internal AND to_page_id IS NOT NULL AND from_page_id <> to_page_id
            AND NOT ('nofollow' = ANY(rel))
        ) e
      SQL
      decoder = PG::TextDecoder::Array.new(elements_type: PG::TextDecoder::Integer.new)
      [ decoder.decode(row[0]), decoder.decode(row[1]) ]
    end

    # ids: node ids; sources/targets: parallel edge arrays. Returns ranks in the order of ids.
    def compute(ids, sources, targets)
      n = ids.size
      index = ids.each_with_index.to_h
      from = []
      to = []
      sources.each_with_index do |source, i|
        a = index[source]
        b = index[targets[i]]
        next unless a && b

        from << a
        to << b
      end
      out_degree = Array.new(n, 0)
      from.each { out_degree[_1] += 1 }

      rank = Array.new(n, 1.0 / n)
      ITERATIONS.times do
        dangling = 0.0
        n.times { |i| dangling += rank[i] if out_degree[i].zero? }
        base = (1 - DAMPING) / n + DAMPING * dangling / n
        next_rank = Array.new(n, base)
        from.each_with_index do |a, e|
          next_rank[to[e]] += DAMPING * rank[a] / out_degree[a]
        end
        rank = next_rank
      end
      rank
    end
  end
end
