# Process-local store for controller rate limits. Fine for the single-process personal deployment;
# switch to a Redis cache store before running several API processes.
module RateLimitStore
  STORE = ActiveSupport::Cache::MemoryStore.new
end
