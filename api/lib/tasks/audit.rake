namespace :audit do
  desc "Re-run on-page extraction from stored HTML: bin/rails audit:reextract CRAWL_ID=1"
  task reextract: :environment do
    crawl = Crawl.find(ENV.fetch("CRAWL_ID"))
    Crawling::PageAnalysis.reextract(crawl)
    puts "Re-extraídas #{crawl.pages.count} páginas del crawl #{crawl.id}"
  end
end
