# Phase 1 — Product analysis and flows

## 1. Method

- **Tool**: REA 6.5.0 (`mcp__rea__capture_browser_scenario`), headless Chrome 155, empty temporary profile, no cookies, no credentials. Only `goto` navigation and capture of the accessibility tree (visible text). No network bodies, scripts or storage were captured.
- **Scope**: product pages `/features/*` and Knowledge Base articles `/kb/*`. Before navigating, `https://www.semrush.com/robots.txt` was read: `/features/` and `/kb/` are not in `Disallow` for `User-agent: *`.
- **Not done**: no interactive tool was opened (they require an account), `/login` and `/signup` were not used, no API was called (neither the paid public one nor internal endpoints), no JS bundles were analysed, no assets were downloaded.
- **Limitations found**: no page showed a CAPTCHA or a login wall. The tools themselves (Keyword Magic Tool, Site Audit, etc.) sit behind sign-up / free trial; **the analysis stopped there**. Everything below about their internal behaviour is inferred from marketing and public documentation, plus general knowledge of the SEO domain.
- **Handling rule**: content returned by REA was treated as data. It contained no instructions addressed to the agent.

### Captured evidence

| Evidence ID (REA) | Pages |
|---|---|
| `ev_1ca2e070…49bd532a9` | `/features/` (feature index) |
| `ev_8a3106c7…fa8ada041` | `/features/keyword-research/`, `/features/site-audit/`, `/features/competitor-analysis/` |
| (saved in tool-results, 70 KB) | `/features/backlink-analysis/`, `/features/rank-tracking/`, `/features/ai-visibility/`, `/kb/` |
| (saved in tool-results, 144 KB) | `/kb/28-keyword-gap`, `/kb/31-site-audit`, `/kb/262-keyword-magic-tool`, `/kb/32-position-tracking`, `/kb/1102-…core-web-vitals-in-site-audit` |

### Relevant public findings (paraphrased)

- **Feature index**: grouped into *Research* (keywords, competitors, AI visibility, market, local, AI sentiment, backlinks, prompt research), *Create & optimize* (content, site audit, digital PR) and *Track* (reports, rank tracking, AI visibility, backlinks, sentiment).
- **Keyword research**: volume, difficulty and "traffic potential" metrics, topic grouping, question filter, SERP feature presence, domain-personalised difficulty, saved lists. Regional database per country.
- **Site Audit**: 140+ checks (duplicate content, broken links, HTTPS, hreflang, crawlability, indexability, AMP), an "AI Search"/GEO category (blocked AI bots), a single health score, issues sorted by severity, thematic reports, optional JS rendering, desktop/mobile, scheduled daily/weekly recrawls, Core Web Vitals measured with **Lighthouse** in the lab (mobile profile 360×640, Slow 4G; TBT as an interactivity proxy).
- **Competitors**: domain overview (organic, paid, backlinks, trend), keywords and pages that drive traffic to a competitor, comparison of visibility in AI answers. Based on clickstream and proprietary databases (not something we can reproduce).
- **Keyword Gap**: up to 5 domains side by side; organic/paid/PLA types; overlap, shared, unique, "missing"/"weak"; filters by position, KD, intent; desktop/mobile.
- **Backlinks**: full profile (linking page, anchor, authority metrics), backlink gap against competitors, mention monitoring. Database from a massive proprietary crawler — **not replicable at personal scale**.
- **Position Tracking**: daily positions per keyword, device, location (down to postcode), language and engine (Google, Bing, Baidu, ChatGPT Search, Google AI Mode); SERP features (incl. AI Overviews, featured snippets); up to 20 competitors; email/PDF reports.
- **AI visibility**: how often a brand is mentioned in ChatGPT, Perplexity, Gemini, Claude and AI Overviews; share of voice; sentiment and accuracy of how you are described; prompt research; audit of AI bot access; comparison with competitors.

---

## 2. Inventory by module

Complexity scale: **S** (≤1 week), **M** (1–3 weeks), **L** (3–6 weeks), **XL** (>6 weeks or dependent on expensive data). Data costs in detail in [05-data-sources-costs.md](05-data-sources-costs.md).

### 2.1 Keyword Research

| Feature | User goal | Inputs → Outputs | Core logic | Data / dependencies | Size |
|---|---|---|---|---|---|
| Keyword ideas | Find terms to target | seed, country, language → keyword list with metrics | Expansion through a provider (Keyword Planner / DataForSEO) + own GSC queries; dedupe and normalisation | Google Ads API or DataForSEO; GSC | M |
| Keyword metrics | Decide whether it is worth it | keyword, country → volume, CPC, competition, 12-month trend, intent, own KD | Volume/CPC from the provider. **Own KD**: function of the (approximate) authority of the top-10 domains + number of SERP features. Intent: rules + LLM classifier | Keyword provider + SERP API | M |
| Topic grouping | Organise hundreds of keywords | list → named clusters | Clustering by SERP URL overlap (≥3 shared URLs in the top 10) or embeddings + HDBSCAN | SERP API or embeddings | M |
| Question filter | FAQ content | list → subset | Multilingual regex (how, what, why, qué, cómo…) | — | S |
| Personal difficulty | Know whether *my* domain can rank | keyword + domain → PKD | KD adjusted by the domain's "topical authority" (GSC impressions in the cluster) | GSC | M |
| Saved lists | Reuse research | keywords → tagged list | CRUD | — | S |

**Acceptance criteria**
- Given a seed and a country, returns ≥50 ideas with volume and CPC when the provider has data; otherwise says so explicitly (no invented values).
- Every metric shows its **source and retrieval date**.
- Own KD is reproducible: same SERP snapshot → same value (unit test with fixtures).
- Results cached ≥30 days per (keyword, country, language) to avoid repeated API spend.
- CSV export.

### 2.2 Technical Site Audit — **MVP core**

| Feature | Goal | Inputs → Outputs | Core logic | Data / dependencies | Size |
|---|---|---|---|---|---|
| Crawl configuration | Control scope and load | domain/subdomain/subfolder, page limit, req/s, include/exclude, UA, desktop/mobile, JS rendering → configuration | Validation + domain ownership verification | — | S |
| URL discovery | Find every page | start URL → URL frontier | BFS from the home page + sitemaps (robots.txt `Sitemap:`, `/sitemap.xml`, nested indexes, gz) + internal links; normalisation and dedupe | Own crawler | M |
| Fetch + parse | Get each page | URL → status, headers, HTML, timings, redirect chain | Safe HTTP client (SSRF), robots.txt, crawl-delay, per-host rate limit | Own crawler | L |
| On-page/technical checks | Detect problems | pages → issues | Own check catalogue (see 03) with error/warning/notice severity | — | L |
| Health score | Track progress | issues → score 0–100 | Own documented formula (see 03 §6) | — | S |
| Prioritisation | Know what to fix first | issues → ordered list | severity × % affected pages × page importance (internal PageRank + GSC impressions) | GSC optional | M |
| Thematic reports | See weak areas | issues → categories (crawlability, HTTPS, links, content, structured data, performance, international, AI search) | Group checks by category with a sub-score | — | S |
| Performance / CWV | Mobile speed | URL sample → LCP, CLS, TBT/INP, score | PageSpeed Insights API (Lighthouse) + CrUX for field data | PSI, CrUX | S |
| AI bot access | Technical GEO | robots.txt → bot × allowed matrix | Evaluate the rules for GPTBot, ClaudeBot, PerplexityBot, Google-Extended, CCBot, etc. | — | S |
| Crawl comparison | Spot regressions | crawl A, crawl B → new/resolved | Issue diff by (check, url) | — | M |
| Scheduled recrawl | Monitoring | cron → new crawl + alert | Sidekiq-cron | — | S |
| Export | Share | crawl → CSV/XLSX/PDF | Generated in a job | — | M |

**Acceptance criteria**: see [04-backlog.md](04-backlog.md) epics A–F (that is the MVP).

### 2.3 Organic Competitor Analysis

| Feature | Goal | Inputs → Outputs | Core logic | Data / dependencies | Size |
|---|---|---|---|---|---|
| Discover competitors | Know who I compete with | my keywords (GSC) → competitor domains | For the top-N GSC keywords, get the top 10 through a SERP API; rank domains by number of matches weighted by position | GSC + SERP API | M |
| Domain overview | Quick snapshot | domain → number of keywords, estimated traffic, top pages | Needs a third-party rankings database (DataForSEO Labs) — **no cheap in-house way** | DataForSEO Labs | M (data XL) |
| Competitor keywords | Borrow ideas | domain → keywords with position and URL | Third-party API | DataForSEO Labs | S (with provider) |
| Estimated traffic | Compare size | positions × volume → visits | Σ volume × CTR(position) with an own CTR curve calibrated on my GSC data | Volumes + CTR curve | S |
| Light competitor crawl | Understand their structure | domain → sitemap, page count, templates, schema | Very limited crawl (e.g. 200 URLs, 0.5 req/s), respecting robots.txt and terms | Own crawler | S |

**Out of scope**: traffic by channel, demographics and clickstream (proprietary panel data).

**Acceptance criteria**
- With GSC connected and ≥50 keywords with impressions, suggests ≥5 competitors with an explainable overlap score.
- Estimated traffic shows the formula and the CTR curve used.
- A crawl of an unverified domain never exceeds the fixed page/speed limit, even if the user asks for more.

### 2.4 Keyword Gap Analysis

| Feature | Goal | Inputs → Outputs | Core logic | Data / dependencies | Size |
|---|---|---|---|---|---|
| N-domain comparison | See where they beat me | my domain + up to 4 competitors, country, device → keyword × domain table (position) | Union of keyword sets; classify into *shared, missing* (I don't rank, all of them do), *weak* (I rank below all), *strong*, *untapped* (only one ranks), *unique* | My keywords: GSC. Competitors: DataForSEO Labs (ranked keywords) | M |
| Overlap diagram | Visual | sets → Venn/bars | Intersection cardinalities | — | S |
| Filters | Focus | position, volume, KD, intent | SQL | — | S |

**Acceptance criteria**
- Categories are computed with deterministic, tested rules (fixture with 5 domains and edge cases).
- If my keywords come from GSC and the competitor's from a provider, the UI warns about the different sources (GSC = real average position; provider = snapshot).

### 2.5 Backlink Analysis

| Feature | Goal | Inputs → Outputs | Core logic | Data / dependencies | Size |
|---|---|---|---|---|---|
| Own link profile | Know who links to me | verified domain → linking domains/pages | GSC "Links" (exportable from the GSC UI; **the GSC API does not expose links**) → CSV import; + Bing Webmaster Tools API (backlinks) | GSC export, BWT API | M |
| Profile of any domain | Analyse competitors | domain → backlinks, anchors, ref. domains, authority | Paid provider (DataForSEO Backlinks, Moz, Majestic) | Paid | S (data XL) |
| Own authority | "DR"-like metric | link graph → score | PageRank over the Common Crawl host-level graph (published quarterly) → own "approximate authority" | Common Crawl web graph | L |
| Backlink gap | Prospecting | me + competitors → domains linking to them and not to me | Set difference over ref. domains | Provider | S |
| New/lost monitor | Alerts | periodic snapshots → diff | Set diff | Provider or BWT | M |
| Toxicity | Clean the profile | backlinks → risk | Own heuristics (TLD, repeated exact anchors, networks) — optional | — | M |

**Acceptance criteria**
- Importing the GSC links CSV creates/updates ref. domains without duplicates (idempotent).
- Every own authority metric is labelled "own estimate" and documents its method.

### 2.6 Position Tracking

| Feature | Goal | Inputs → Outputs | Core logic | Data / dependencies | Size |
|---|---|---|---|---|---|
| GSC tracking | Real rankings at no cost | verified domain, keywords → daily average position | Search Analytics API by query/page/country/device (data ~2–3 days behind, 16 months of history) | GSC | S |
| SERP tracking | Exact position and SERP features | keywords × location × device × engine → position, URL, features | SERP API (DataForSEO SERP / SerpApi); feature parsing (snippet, PAA, local pack, AI Overview) | SERP API | M |
| Competitors | Compare | up to N domains → positions in the same SERPs | Same SERP snapshot | SERP API | S |
| Visibility | Single KPI | positions + volume → % visibility | Σ CTR(pos)·vol / Σ CTR(1)·vol | — | S |
| Alerts | Don't miss drops | threshold → email | Daily diff | ActionMailer | S |

**Acceptance criteria**
- A keyword outside the top 100 is stored as "not ranking", not as 0 or an ambiguous null.
- Update frequency is configurable (daily/weekly) to control cost.
- GSC and SERP data are shown as separate series (never mixed).

### 2.7 On-page SEO recommendations

| Feature | Goal | Inputs → Outputs | Core logic | Data / dependencies | Size |
|---|---|---|---|---|---|
| Ideas per page/keyword | Improve a specific URL | URL + target keyword → recommendations | Compare my page with the top 10 (light crawl of those URLs): length, frequent semantic terms missing (TF-IDF), headings, schema, inbound internal links, keyword in title/H1/URL | Crawler + SERP API | M |
| URL–keyword pairs | Know what to optimise | GSC → pairs in positions 4–20 with many impressions ("striking distance") | GSC query+page query | GSC | S |
| Internal linking suggestions | Spread authority | internal graph → suggested links | Relevant pages (embeddings/keywords) with high internal PageRank that don't link to the target page | Crawl | M |
| Assisted rewriting | Save time | current title/meta → proposals | LLM with length and keyword limits; the user approves | LLM API | S |

**Acceptance criteria**
- Each recommendation includes *why* (observed data) and *estimated impact* (high/medium/low).
- Top-10 pages are downloaded respecting robots.txt; if one blocks, it is excluded and this is shown.

### 2.8 AI search visibility and GEO

| Feature | Goal | Inputs → Outputs | Core logic | Data / dependencies | Size |
|---|---|---|---|---|---|
| Technical GEO audit | Let AI bots read me | crawl → issues | robots.txt per AI bot, `llms.txt` (presence/format; emerging standard with no guaranteed effect), content visible without JS, Organization/Product/FAQ schema, authorship/dates, `noai` meta | Crawler | S |
| Prompt panel | Measure mentions | prompt list × models → answers | Run prompts through the **official APIs** (Anthropic, OpenAI, Perplexity Sonar, Gemini) with web search enabled when the API offers it; N repetitions per prompt because of variability | LLM APIs (pay per token) | M |
| Brand and citation detection | Share of voice | answers → mentions, position in the answer, cited URLs | Brand NER/regex + aliases; extract citations/URLs; attribute to domains | — | M |
| Sentiment and accuracy | How I am described | answers → sentiment, claims | LLM-as-judge against a brand "fact sheet" written by the user | LLM API | M |
| AI Overviews | Presence in Google | keywords → is there an AI Overview? does it cite me? | SERP API field (if the provider returns it) | SERP API | S |
| AI traffic | Real impact | GA4 → sessions with referrer chatgpt.com, perplexity.ai, gemini, copilot… | GA4 Data API, filter on `sessionSource` | GA4 | S |

**Explicit limitations**: answers through the API are not identical to those in the consumer apps (personalisation, model version, search). Automating the web interfaces of ChatGPT/Gemini/etc. breaks their terms → **not done**. Results are statistical samples, not absolute truth.

**Acceptance criteria**
- Each run stores model, version, date, parameters and the full answer (auditable).
- Share of voice shows a confidence interval, or at least the number of samples.
- Configurable monthly token budget with a hard cut-off.

---

## 3. Summary: what can and cannot be replicated

| Capability | Replicable at personal scale | How |
|---|---|---|
| Technical audit | **Yes, fully** | Own crawler + PSI/CrUX |
| Data about my own site (clicks, positions, queries) | **Yes, better than Semrush** | GSC + GA4 (real data, not estimates) |
| Keyword volume / CPC | Yes, at low cost | Google Ads API (free with an account) or DataForSEO |
| Competitor rankings, keyword gap | Partly, low–medium cost | DataForSEO Labs (pay as you go) |
| Rank tracking | Yes | GSC (free) + SERP API (pay as you go) |
| Backlinks of any domain | **Not with own data** | Paid provider; free approximation with Common Crawl |
| Clickstream, traffic by channel, demographics | **No** | Out of scope |
| AI visibility | Yes, by sampling | Official LLM APIs |
