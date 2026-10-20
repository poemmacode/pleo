# ADR 0003 — SafeHttp design (Epic A)

Date: 2026-10-17 · Status: accepted

## Decisions

1. **IP pinned with `Net::HTTP#ipaddr=`**. In Ruby 3.3 (net-http 0.4) the TCP socket is opened to `ipaddr`, while the `Host` header, SNI and `post_connection_check` use the hostname. That connects to the IP we validated without losing TLS verification, and avoids an extra HTTP gem.
2. **Resolution with `Resolv::DNS`** (A + AAAA), not `getaddrinfo`, so `/etc/hosts` plays no part. The host is rejected if **any** of its records is blocked.
3. **IPv6 forms that carry an IPv4 inside** (mapped, compatible, NAT64 `64:ff9b::/96`, 6to4 `2002::/16`) are judged by the IPv4 they contain. Teredo (`2001::/32`) is blocked entirely.
4. **Numeric-only hosts** (`2130706433`, `0x7f.1`, `0177.0.0.1`) are always rejected, even though our resolver does not read them as IPs, because other components (the renderer's browser, libraries) do.
5. **Own decompression (`BodyReader`)**. `Net::HTTP`'s inflater cannot be interrupted mid-body (it fails on close with `closed?` on the Inflater). We send `Accept-Encoding` ourselves, which turns off automatic decoding, and inflate as a stream. The byte limit applies to the **decompressed** content (protects against gzip bombs).
6. **Per-host rate limit with GCRA in Redis** (Lua script and Redis clock): burst of 1, so with `rps = 2` requests go out ≥ 0.5 s apart however many workers there are. Jobs use `reserve` and re-enqueue; one-off downloads use `acquire`.
7. **`AdaptiveRate` is an immutable object with no I/O**. Epic B persists it on the crawl row (with `with_lock`) and acts on the decision (`:slow_down` / `:pause`).
8. **IP allow list for tests only**: `SafeHttp.config.allow_ips_for_tests!` raises `SecurityError` outside `test`, and `IpPolicy` ignores it outside `test` even if it is populated. Both behaviours have specs.

## Known limitations

- The TLS path was checked against real sites (example.com, wikipedia.org), but there is no automated spec with a local HTTPS server.
- The deployment's internal names (`postgres`, `redis`, `renderer`) are blocked because they have no dot or resolve to private IPs; if deployed with public names, they should be added to `HostPolicy::BLOCKED_HOSTNAMES`.
- The infrastructure layers (IMDSv2 with hop limit 1, security group egress, Smokescreen) are still pending for deployment.
