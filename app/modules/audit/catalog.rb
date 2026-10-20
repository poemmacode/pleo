module Audit
  # Every check, in report order.
  module Catalog
    CHECKS = [
      Checks::Crawlability::Http4xx, Checks::Crawlability::Http5xx, Checks::Crawlability::FetchFailed,
      Checks::Crawlability::RedirectChain, Checks::Crawlability::RedirectLoop, Checks::Crawlability::RedirectTemporary,
      Checks::Crawlability::RobotsBlockedLinked, Checks::Crawlability::SitemapNon200, Checks::Crawlability::SitemapNoindex,
      Checks::Crawlability::SitemapMissing, Checks::Crawlability::Orphan, Checks::Crawlability::Deep,
      Checks::Indexability::Noindex, Checks::Indexability::CanonicalMissing, Checks::Indexability::CanonicalToNon200,
      Checks::Indexability::CanonicalToNoindex, Checks::Indexability::CanonicalMultiple, Checks::Indexability::CanonicalInvalid,
      Checks::Indexability::CanonicalChain, Checks::Indexability::HreflangNoReturn, Checks::Indexability::HreflangInvalidCode,
      Checks::Metadata::TitleMissing, Checks::Metadata::TitleDuplicate, Checks::Metadata::TitleTooLong,
      Checks::Metadata::TitleTooShort, Checks::Metadata::TitleMultiple, Checks::Metadata::DescriptionMissing,
      Checks::Metadata::DescriptionDuplicate, Checks::Metadata::DescriptionLength,
      Checks::Content::H1Missing, Checks::Content::H1Multiple, Checks::Content::HeadingsSkipped, Checks::Content::H1EqualsTitle,
      Checks::Content::Thin, Checks::Content::NearDuplicate, Checks::Content::ImagesMissingAlt,
      Checks::Links::InternalBroken, Checks::Links::ExternalBroken, Checks::Links::InternalNofollow,
      Checks::Links::ToRedirect, Checks::Links::TooMany,
      Checks::StructuredData::InvalidJson, Checks::StructuredData::UnknownType, Checks::StructuredData::MissingRequired,
      Checks::StructuredData::None,
      Checks::Https::NotUsed, Checks::Https::MixedContent, Checks::Https::HttpLinks, Checks::Https::CertInvalid,
      Checks::MobilePerformance::ViewportMissing, Checks::MobilePerformance::PageTooLarge, Checks::MobilePerformance::SlowResponse,
      Checks::MobilePerformance::LcpPoor, Checks::MobilePerformance::ClsPoor, Checks::MobilePerformance::InpPoor,
      Checks::MobilePerformance::ScoreLow,
      Checks::AiSearch::BotsBlocked, Checks::AiSearch::LlmsTxtMissing
    ].freeze

    module_function

    def definitions = CHECKS.map(&:definition)

    def sync_definitions!
      CheckDefinition.upsert_all(definitions, unique_by: :key,
                                 update_only: %i[category severity weight title description how_to_fix])
    end
  end
end
