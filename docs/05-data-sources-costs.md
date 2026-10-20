# Data sources and costs

> **Note**: prices and quotas are approximate, based on public information known up to 2026, and **must be checked on each provider's official page before signing up**. Values with the most uncertainty are marked ⚠︎.

## 1. Sources

| Source | Modules | What it provides | Access / authorisation | Quota / limits | Cost |
|---|---|---|---|---|---|
| **Own crawler** | Audit, OnPage, Competitors (light), technical GEO | HTML, statuses, links, metadata, schema | Own; robots.txt + domain verification | Whatever we set (03 §3.1) | Infrastructure only |
| **PageSpeed Insights API v5** | Performance | Lighthouse lab (LCP, CLS, TBT…), opportunities; embedded CrUX | Google Cloud API key | ≈ 25,000 queries/day, ≈ 400 per 100 s | **Free** |
| **CrUX API** | Performance | p75 field data (LCP, INP, CLS) per URL/origin, 28 days | API key | ≈ 150 queries/min | **Free** |
| **Google Search Console API** | SearchConsole, RankTracking, OnPage, Competitors | Clicks, impressions, CTR, position by query/page/country/device (16 months); sitemaps; URL Inspection | OAuth (`webmasters.readonly`), the user's own properties only | Search Analytics ≈ 1,200 QPM per site; URL Inspection ≈ 2,000/day and 600/min per property | **Free** |
| GSC — links report | Backlinks | Top linking domains/pages | Manual CSV export from the UI (the API does **not** expose links) | Partial sample | **Free** |
| **GA4 Data API** | Analytics, GEO | Sessions by source/landing page; traffic from AI referrers | OAuth (`analytics.readonly`) | Token quotas per property (≈ 200k tokens/day on standard properties ⚠︎) | **Free** |
| **Bing Webmaster Tools API** | Backlinks, RankTracking | Inbound links, queries and positions in Bing | BWT account API key, verified site | Moderate daily limits | **Free** |
| **Google Ads API — Keyword Planner** | Keywords | Keyword ideas, monthly volume, CPC, competition, trend | Google Ads account + manager account + *developer token* with Basic access (application required) | Accounts without active spend get volumes as ranges | **Free** (Ads account required) |
| **DataForSEO** (pay as you go) | Keywords, Serp, RankTracking, Competitors, Gap | Google/Bing SERPs (incl. AI Overview when present), volumes, *ranked keywords* for any domain, backlinks | Contract and API key; licence to use the data | Minimum deposit ≈ 50 USD ⚠︎ | Standard-queue SERP ≈ 0.0006 USD/query, *live* ≈ 0.002 ⚠︎; volumes ≈ 0.05 USD per batch of up to 1,000 keywords ⚠︎; Labs ≈ 0.01 USD/request + 0.0001/item ⚠︎; Backlinks API with a monthly commitment ≈ 100 USD ⚠︎ |
| SerpApi (SERP alternative) | Serp, RankTracking | Parsed SERPs, many engines | API key | Small free plan | From ≈ 75 USD/month for 5,000 searches ⚠︎ |
| **Common Crawl** | Backlinks (approximate authority) | Host/domain-level web graph published periodically; WARC | Open data (AWS Open Data) under its terms of use | Several GB to download per release | **Free** (+ compute for PageRank) |
| Moz Links API | Backlinks | DA/PA, links | Subscription | Per rows/month | Tens to hundreds of USD/month ⚠︎ |
| Majestic API | Backlinks | Trust/Citation Flow, links | API subscription | — | ≈ 400 USD/month ⚠︎ |
| Ahrefs API | Backlinks, Keywords | Full data | Enterprise plans only | — | ≥ 1,000 USD/month ⚠︎ — **not recommended** |
| Semrush API | All | Semrush data | Business plan + API units | — | High ⚠︎ — **excluded** by the independence goal |
| **Anthropic API** (Claude) | GEO, OnPage (rewriting), intent classification | Answers with web search, sentiment judging | API key | Rate limits per tier | Per token + web search tool fee; see the current price list |
| OpenAI API | GEO | Answers with web search | API key | Per tier | Per token + searches ⚠︎ |
| Perplexity Sonar API | GEO | Answers with citations | API key | — | Per token + per-request fee ⚠︎ |
| Gemini API | GEO | Answers *grounded* in Google Search | API key | Limited free quota | Per token + grounding ⚠︎ |
| schema.org vocabulary | Audit (schema) | Types and properties | Public download (CC BY-SA 3.0) | — | **Free** |
| Public Suffix List | Crawling (scope) | Registrable domain | Public (MPL 2.0) | — | **Free** |

### Rejected sources (and why)

| Source | Reason |
|---|---|
| Scraping Google/Bing SERPs directly | Forbidden by their terms and protected by anti-bot measures |
| Automating the ChatGPT, Gemini, Perplexity or Claude web apps | Forbidden by their terms; their official APIs are used instead |
| Semrush internal endpoints or private API | Outside the project's limits |
| Google Custom Search JSON API | Closed to new customers with an announced retirement ⚠︎; it also does not reflect the real SERP |
| Clickstream / panel data | No affordable authorised source |

## 2. Monthly cost scenarios (personal use)

Assumptions: 1–3 own sites, ~5,000 pages each, 1 crawl a week.

| Scenario | Includes | Data | Infra | Approx. total |
|---|---|---|---|---|
| **Local MVP** | Crawler + PSI on your Mac | 0 | 0 | **0 USD** |
| **Hosted MVP (today)** | Render free plan (see [deploy.md](deploy.md)) | 0 | 0 | **0 USD** (with the free plan's limits) |
| **Hosted MVP (more capacity)** | The above on 1 EC2/Lightsail with Kamal | 0 | 30–60 | **30–60 USD** |
| + GSC, GA4, BWT, CrUX | Phases 2–3 | 0 | — | **+0** |
| + Keywords (Keyword Planner) | Phase 4 | 0 | — | **+0** |
| + Keywords (DataForSEO) | ~200 volume/idea queries a month | 1–5 | — | **+1–5 USD** |
| + SERP rank tracking | 200 keywords, daily, standard queue ≈ 6,000 SERPs | ≈ 4 | — | **+≈4 USD** |
| + Competitors / Gap | 20 domain analyses a month in Labs | 2–10 | — | **+2–10 USD** |
| + GEO | 50 prompts × 4 models × 3 repetitions, weekly ≈ 2,400 calls | 20–80 ⚠︎ | — | **+20–80 USD** |
| + Third-party backlinks | DataForSEO Backlinks or Moz | 100–400 | — | **+100–400 USD** (optional) |

Recommendation: get as far as GEO for **< 150 USD/month** in total, and only pay for backlinks if the Common Crawl + GSC + BWT module turns out to be insufficient.

## 3. Spend control (design requirement)

- Every provider goes through `Providers::<X>`, which records `api_usage` (units, estimated cost, cached yes/no).
- Monthly budget per project; alert at 80 %, hard cut-off at 100 % (calls fail with a `budget_exceeded` error).
- Cache by key (keyword+country+language, domain+date…) with a TTL per type: volumes 30 d, SERP 1 d, competitor ranked keywords 7 d.
- A `/usage` page with spend per provider and an end-of-month projection.
