# Deploying to Render (free plan)

The repository includes a Blueprint, [`render.yaml`](../render.yaml), that creates three free resources:

| Resource | What it is |
|---|---|
| `seo-platform` (web, `free`) | Puma with **embedded Sidekiq** (`SIDEKIQ_EMBEDDED=true`). The free plan has no workers. |
| `seo-platform-db` (Postgres, `free`) | Database. |
| `seo-platform-kv` (Key Value, `free`) | Redis for Sidekiq, Action Cable and the per-host rate limiter. |

## Steps

1. **Push the repository to GitHub** (or GitLab). Render deploys from a remote repository:

   ```bash
   git remote add origin git@github.com:YOUR_USER/seo-platform.git
   ```

   ```bash
   git push -u origin main
   ```

   It can be private; Render will ask for access to it. `config/master.key` is in `.gitignore` and is **not** pushed.
2. In Render: **New → Blueprint**, pick the repository and the `main` branch. Render reads `render.yaml` and asks for three secret values:
   - `RAILS_MASTER_KEY`: the contents of `config/master.key` (no line breaks).
   - `ADMIN_EMAIL` and `ADMIN_PASSWORD`: the admin account, with a password of at least 12 characters. On every boot `bin/rails users:ensure` creates it, makes it the only admin and resets its password to this value if you change it here (which also signs it out everywhere). The password cannot be changed from the app. Everyone else signs up at `/sign_up` as a member.
3. Click **Apply**. The build runs `bundle install` and `assets:precompile`. Boot runs `db:prepare`, `users:ensure` and Puma.
4. Open `https://seo-platform.onrender.com` (or whatever name Render assigns) and sign in. The interface is in English; switch to Spanish with the **ES** button in the top bar (the choice is saved on your user).

Sign-up is open by default (`REGISTRATION_OPEN=true` in `render.yaml`). Set it to `false` in **Environment** to keep the deployment to the admin only.

Render sets `RENDER_EXTERNAL_URL`, `DATABASE_URL` and `REDIS_URL`. The bot's User-Agent links to `/bot`, a public page explaining what it does and how to block it.

## PageSpeed Insights (performance and Core Web Vitals)

The audit measures mobile performance for a sample of pages with the PageSpeed Insights API. Without a key the API uses a shared anonymous quota that is usually exhausted, so you need a **free Google API key**:

1. At https://console.cloud.google.com create or pick a project.
2. **APIs & Services → Library**: search for **PageSpeed Insights API** and click **Enable**.
3. **APIs & Services → Credentials → Create credentials → API key**.
4. Recommended: on the key, **API restrictions → Restrict key → PageSpeed Insights API**, so it cannot be used for anything else.
5. In Render, on the web service → **Environment**, add `PAGESPEED_API_KEY` with that key and save (it redeploys). Since the variable was added after the Blueprint was created, it has to be set by hand.

Optional: `PAGESPEED_DAILY_LIMIT` (500 by default) caps daily measurements across all crawls. Google's free quota is much larger.

Each measurement takes 10–60 s on Google's servers. 4 pages are measured at a time at 1 request per second, so the default sample (10 pages) adds roughly a minute to the audit.

## Free plan limits (per Render's documentation, October 2026)

- **The web service sleeps after 15 minutes without inbound traffic** and takes about a minute to wake up. While it sleeps, Sidekiq stops too: a long crawl is effectively paused and carries on when the app is opened again, because jobs stay in Key Value and abandoned claims are recovered. A 500-page crawl at 1 req/s takes about 9 minutes; keeping the crawl page open while it runs is enough.
- **Free Postgres expires 30 days after creation** (plus a 14-day grace period), has no backups and is 1 GB. Fine for trying things out; for data you want to keep, move to a paid plan.
- **Free Key Value is not persistent**: if it restarts, queued jobs are lost. A running crawl may get stuck at "Crawling"; start it again.
- **No Shell and no one-off jobs.** That is why the user is created by `users:ensure` and migrations run at boot.
- **750 instance hours a month** per workspace (sleeping hours do not count).
- **512 MB of RAM and 0.1 CPU**: Puma (3 threads) + Sidekiq (3 threads) fit for small and medium crawls; crawls of thousands of pages will be slow.

## Production security

- SSRF protection lives in the application (`SafeHttp`), so it works the same on Render. The infrastructure layers from the design (blocking egress to private networks, IMDSv2, Smokescreen) do not exist here; they would only matter if the app were opened to other users.
- `force_ssl` is on; `/up` is excluded from the redirect for the health check.
- Only the `ADMIN_EMAIL` account is an admin. Members only see their own records and cannot delete projects, verified or crawled domains, crawls or users.
- `/status` records a health check every 5 minutes, but only while the service is awake: the free plan's sleep shows up as "no data", not as downtime. For real outage alerts, point an external monitor at `/up` or `/status.json`.

## Moving to a paid plan

Change `plan:` in `render.yaml`. A paid plan also lets you:
- split Sidekiq into a `type: worker` service running `bundle exec sidekiq -C config/sidekiq.yml` and drop `SIDEKIQ_EMBEDDED`;
- use `preDeployCommand: bin/rails db:migrate` instead of migrating at boot;
- use the Shell for `bin/rails users:create`.
