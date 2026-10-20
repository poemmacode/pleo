# ADR 0010 — Internationalization (English by default, Spanish available)

Date: 2026-10-20 · Status: accepted

## Context

The interface, check texts, reports, comments and documentation were written in Spanish. The user asked for English as the default language of the app, with Spanish still available, and for the code, comments, specs and documentation to be in English.

## Decisions

1. **Rails I18n with `en` (default) and `es`.** `config.i18n.default_locale = :en`, `available_locales = %i[en es]`. Every user-facing string goes through `t()`; views use lazy lookup (`t(".title")`). `raise_on_missing_translations` is on in development and test, so a missing key fails loudly instead of rendering "translation missing".
2. **Language picker in the top bar, saved on the user.** `users.locale` (default `"en"`). `PATCH /locale` (`LocalesController`) validates the value, stores it in the session and, if someone is signed in, on the user. On the sign-in page the choice lives in the session and is copied to the user on sign-in. The `Localization` concern wraps each request in `I18n.with_locale(user locale || session locale || default)`. No locale in the URL: the app is private, so there are no indexable localized URLs to worry about.
3. **Check texts in locale files**, not in the database or the Ruby DSL. `config/locales/checks.{en,es}.yml` hold `title`, `description` and `fix` for each check, nested by key (`checks.http.4xx.title`, because I18n treats dots as nesting). `check_definitions` keeps only `category`, `severity` and `weight`; `Audit::Check.title` / `CheckDefinition#title` read from I18n. The English texts were written from scratch, like the Spanish ones.
4. **Domain errors as symbols.** Models and services (`Domain::HostNormalizer`, `CrawlConfig`, `Domain::Verifier`, `Crawling::CreateCrawl`) report error codes; the text comes from `activerecord.errors` / `activemodel.errors` or the relevant scope. Low-level messages that only reach logs (SafeHttp, extractors) are plain English.
5. **Live updates per language.** Broadcasts are rendered outside a request, so they cannot know the viewer's language. The crawl page subscribes to `[crawl, :progress, locale]`, and `Crawling::ProgressBroadcaster` / `Reports::Broadcaster` render each partial once per available locale inside `I18n.with_locale`. With two languages this doubles the rendering work of a broadcast, which is already throttled to one every 2 s per crawl.
6. **Reports keep the requester's language.** `reports.locale` is set from `I18n.locale` when the report is requested, and `GenerateReportJob` renders inside `I18n.with_locale(report.locale)`. Numbers use the locale's separators.
7. **Static error pages** (`public/404.html`, `422.html`, `500.html`) are in English only; Rails serves them without going through the app.
8. **Specs check both files stay in sync**: `spec/i18n_spec.rb` fails if a key exists in `en.yml` but not in `es.yml` (or the other way round, excluding Rails' own date/number formats), or if a check lacks a text in either language.

## Consequences

- Adding a language means adding `config/locales/<locale>.yml` and `checks.<locale>.yml` and listing it in `available_locales`; broadcasts pick it up automatically.
- `check_definitions.title/description/how_to_fix` columns were dropped; a migration adds `users.locale` and `reports.locale`.
- The `I18n` option `scope` is reserved, so it cannot be used as an interpolation key (we use `where` instead).
