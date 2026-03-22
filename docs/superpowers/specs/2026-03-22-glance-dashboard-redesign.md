# Glance Dashboard Redesign

**Date:** 2026-03-22
**File:** `roles/glance/templates/glance.yml.j2`

## Goal

Transform the Glance home page into a curated content aggregator (self-hosted Pocket replacement) — topic-organized news, articles, and videos surfaced passively across personal interests. Reduces social media dependency by making content come to the user.

The Infrastructure page remains unchanged.

## What's Removed

- `twitch-channels` widget (left column)
- `lobsters` widget (from the HN group in center column)
- `releases` widget (right column)
- Generic dev blog RSS feeds: ciechanow.ski, joshwcomeau, samwho, ishadeed — selfh.st moves to Homelab RSS row

## Column Structure Change

**Current order:** small (calendar, RSS, twitch) | full (search, HN+lobsters, videos, reddit) | small (weather, markets, releases)

**New order:** small (calendar, **weather**, breaking news) | full (search, HN, 5× RSS rows, reddit, YouTube) | small (markets, parenting/health RSS)

Weather moves from the right column to the left column. The releases widget is removed. The overall 3-column structure is preserved.

## Layout: Home Page

### Left Column (small)

| Widget | Config |
|---|---|
| Calendar | `first-day-of-week: sunday` ← change from `monday` |
| Weather | Frankenmuth, MI — imperial, 12h (unchanged, moved from right column) |
| Breaking News RSS | `style: vertical-list`, `cache: 1h`, `collapse-after: 3` — AP News, Reuters, Ars Technica |

### Center Column (full)

| Widget | Config |
|---|---|
| Search | Kagi (unchanged) |
| Hacker News | Solo widget, no group wrapper (lobsters removed) |
| Tech & AI RSS | `style: horizontal-cards`, `cache: 1h`, `limit: 20`, `collapse-after: 5` — The Verge, Anthropic blog, Simon Willison, Latent Space, r/ClaudeAI |
| Homelab RSS | `style: horizontal-cards`, `cache: 2h`, `limit: 15`, `collapse-after: 5` — selfh.st, r/homelab, LinuxServer.io blog |
| Gaming RSS | `style: horizontal-cards`, `cache: 2h`, `limit: 15`, `collapse-after: 5` — PC Gamer, IGN, r/Borderlands4, r/gaming |
| DIY/Making RSS | `style: horizontal-cards`, `cache: 6h`, `limit: 15`, `collapse-after: 5` — r/3Dprinting, r/fermentation, Instructables, Make Magazine |
| Deals & Outdoor RSS | `style: horizontal-cards`, `cache: 1h`, `limit: 15`, `collapse-after: 5` — Slickdeals, r/deals, r/frugalmalefashion, Gear Junkie |
| Reddit group | `cache: 30m`, `show-thumbnails: true` — r/technology + r/selfhosted (r/homelab covered by Homelab RSS row above) |
| YouTube | `style: grid-cards`, `collapse-after-rows: 3` |

### Right Column (small)

| Widget | Config |
|---|---|
| Markets | SPY, BTC-USD, NVDA, AAPL, MSFT (unchanged) |
| Parenting/Health RSS | `style: vertical-list`, `cache: 12h`, `collapse-after: 5` — Fatherly, The Kitchn, Mayo Clinic, r/Parenting |

## YouTube Channels

All IDs confirmed from user-edited template file.

```yaml
- UCYeiozh-4QwuC1sjgCmB92w  # DevOps Toolbox
- UC6gdCj56YK5KxiFf3WSOLtA  # Dr. Will Bulsiewicz (Gut Health MD)
- UCoy6cTJ7Tg0dqS-DI-_REsA  # Chase AI
- UCcjhYlL1WRBjKaJsMH_h7Lg  # Epicurious
- UCsBjURrPoezykLs9EqgamOA  # Fireship
- UCkVfrGwV-iG9bSsgCbrNPxQ  # Better Stack
- UCHkYOD-3fZbuGhwsADBd9ZQ  # Lawrence Systems
- UCxAS_aK7sS2x_bqnlJHDSHw  # America's Test Kitchen
- UC9x0AN7BWHpCDHSm9NiJFJQ  # NetworkChuck
- UChBEbMKI1eCcejTtmI32UEw  # Joshua Weissman
- UCDq5v10l4wkV5-ZBIJJFbzQ  # Ethan Chlebowski
- UCAuUUnT6oDeKwE6v1NGQxug  # TED
- UCR-DXc1voovS8nhAvccRZhg  # Jeff Geerling
- UCsooa4yRKGN_zEE8iknghZA  # TED-Ed
- UCftwRNsjfRo08xYE31tkiyw  # WIRED
- UCOk-gHyjcWZNj3Br4oxwh0A  # Techno Tim
- UCn5fhcGRrCvrmFibPbT6q1A  # Brian Lagerstrom
- UCxQbYGpbdrh-b2ND-AfIybg  # Maker's Muse
- UCb8Rde3uRL1ohROUVg46h1A  # Thomas Sanladerer
- UC2C_jShtL725hvbm1arSV9w  # CGP Grey
- UCzH5n3Ih5kgQoiDAQt2FwLw  # LifebyMikeG
- UCfQgsKhHjSyRLOp9mnffqVg  # RP Strength
- UCFHZHhZaH7Rc_FOMIzUziJA  # Rick Shiels Golf
- UCHnyfMqiRRG1u-2MsSQLbXA  # Veritasium
```

## Implementation Notes

- Reddit RSS feeds use `.rss` suffix: `https://www.reddit.com/r/<subreddit>/.rss`
- Gear Junkie feed URL: `https://gearjunkie.com/feed`
- All other RSS feed URLs must be validated during implementation (Reuters, Mayo Clinic, Make Magazine, LinuxServer.io blog are known to change)
- `r/homelab` intentionally appears only in the Homelab RSS row, not the Reddit group widget, to avoid duplication
- YouTube `style: grid-cards` and `collapse-after-rows` key names should be confirmed against Glance docs during implementation
- The user's template already contains the updated YouTube channel list — preserve it exactly as-is during the rewrite
