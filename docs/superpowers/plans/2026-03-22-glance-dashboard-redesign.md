# Glance Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the Glance home page into a curated content aggregator replacing Pocket — topic-organized RSS rows, YouTube grid, and Reddit widgets across the user's interests.

**Architecture:** Single Jinja2 template file rewrite (`roles/glance/templates/glance.yml.j2`). Home page columns are rebuilt; Infrastructure page is left entirely untouched. Column order changes: weather moves from right to left column, releases widget is removed.

**Tech Stack:** Ansible role template (Jinja2 + YAML), Glance dashboard app, Task runner for validation.

**Spec:** `docs/superpowers/specs/2026-03-22-glance-dashboard-redesign.md`

---

## File Map

| Action | Path |
|---|---|
| Modify | `roles/glance/templates/glance.yml.j2` |

The Infrastructure page (lines 101–188 in original) must be preserved verbatim.

---

### Task 1: Create feature branch

- [ ] **Check current branch**

```bash
git branch
```

Expected: on `dev`

- [ ] **Create and switch to feature branch**

```bash
git checkout -b feature/glance-dashboard-redesign
```

---

### Task 2: Verify RSS feed URLs before writing the template

Several feed URLs need validation before being committed. Run each curl to confirm a 200 response and valid RSS/Atom content.

- [ ] **Verify news feeds**

```bash
curl -sI https://feeds.apnews.com/rss/apf-topnews | head -5
curl -sI https://feeds.reuters.com/reuters/topNews | head -5
curl -sI https://feeds.arstechnica.com/arstechnica/index | head -5
```

If Reuters returns non-200, use `https://feeds.reuters.com/Reuters/worldNews` as fallback, or omit it.

- [ ] **Verify Tech & AI feeds**

```bash
curl -sI https://www.theverge.com/rss/index.xml | head -5
curl -sI https://www.anthropic.com/rss.xml | head -5
curl -sI https://simonwillison.net/atom/everything/ | head -5
curl -sI https://www.latent.space/feed | head -5
```

- [ ] **Verify Homelab feeds**

```bash
curl -sI https://selfh.st/rss/ | head -5
curl -sI https://www.linuxserver.io/blog/feed | head -5
```

If LinuxServer.io returns non-200, try `https://www.linuxserver.io/feed.xml`. If neither works, omit it — selfh.st + r/homelab are sufficient.

- [ ] **Verify Gaming feeds**

```bash
curl -sI https://www.pcgamer.com/rss/ | head -5
curl -sI https://feeds.ign.com/ign/articles | head -5
```

- [ ] **Verify DIY/Making feeds**

```bash
curl -sI https://makezine.com/feed/ | head -5
curl -sI https://www.instructables.com/sitemap.xml | head -5
```

Note: Instructables `sitemap.xml` is not an RSS feed — if it doesn't return feed content, omit it. Make Magazine may have moved to `https://make.co/feed/`.

- [ ] **Verify Deals & Outdoor feeds**

```bash
curl -sI "https://slickdeals.net/newsearch.php?mode=frontpage&searcharea=deals&searchin=first&rss=1" | head -5
curl -sI https://gearjunkie.com/feed | head -5
```

- [ ] **Verify Parenting/Health feeds**

```bash
curl -sI https://www.fatherly.com/feed/ | head -5
curl -sI https://www.thekitchn.com/main.rss | head -5
curl -sI https://www.mayoclinic.org/rss/all-health-information-topics.rss | head -5
```

If Mayo Clinic URL returns non-200, omit it — it has changed multiple times.

- [ ] **Note which URLs failed and mark them to omit in the template**

---

### Task 3: Rewrite left column

Replace the entire left (small) column. This removes the old generic RSS block and `twitch-channels`, and adds breaking news RSS. Weather moves here from the right column.

- [ ] **Open `roles/glance/templates/glance.yml.j2`**

- [ ] **Replace the left column block (from `- size: small` to just before `- size: full`)**

Replace with:

```yaml
      - size: small
        widgets:
          - type: calendar
            first-day-of-week: sunday

          - type: weather
            location: Frankenmuth, Michigan, United States
            units: imperial
            hour-format: 12h

          - type: rss
            title: Breaking News
            style: vertical-list
            cache: 1h
            limit: 10
            collapse-after: 3
            feeds:
              - url: https://feeds.bbci.co.uk/news/rss.xml
                title: BBC News
              - url: https://feeds.npr.org/1001/rss.xml
                title: NPR
              - url: https://feeds.arstechnica.com/arstechnica/index.rss
                title: Ars Technica

```

Omit any feed whose URL failed verification in Task 2.

- [ ] **Run syntax check**

```bash
task syntax
```

Expected: no errors

---

### Task 4: Rewrite center column — search, HN, and RSS rows

Replace the center (full) column's content. Lobsters is removed; HN becomes a solo widget. Five new topic RSS rows are added.

- [ ] **Replace the center column block (from `- size: full` to just before the second `- size: small`)**

Replace with:

```yaml
      - size: full
        widgets:
          - type: search
            search-engine: kagi
            new-tab: true
            autofocus: true
            placeholder: Search Kagi...

          - type: hacker-news

          - type: rss
            title: Tech & AI
            style: horizontal-cards
            cache: 1h
            limit: 20
            collapse-after: 5
            feeds:
              - url: https://www.theverge.com/rss/index.xml
                title: The Verge
              - url: https://simonwillison.net/atom/everything/
                title: Simon Willison
              - url: https://www.latent.space/feed
                title: Latent Space
              - url: https://www.reddit.com/r/ClaudeAI/.rss
                title: r/ClaudeAI

          - type: rss
            title: Homelab
            style: horizontal-cards
            cache: 2h
            limit: 15
            collapse-after: 5
            feeds:
              - url: https://selfh.st/rss/
                title: selfh.st
              - url: https://www.reddit.com/r/homelab/.rss
                title: r/homelab

          - type: rss
            title: Gaming
            style: horizontal-cards
            cache: 2h
            limit: 15
            collapse-after: 5
            feeds:
              - url: https://www.pcgamer.com/rss/
                title: PC Gamer
              - url: https://www.reddit.com/r/Borderlands4/.rss
                title: r/Borderlands4
              - url: https://www.reddit.com/r/gaming/.rss
                title: r/gaming

          - type: rss
            title: DIY & Making
            style: horizontal-cards
            cache: 6h
            limit: 15
            collapse-after: 5
            feeds:
              - url: https://www.reddit.com/r/3Dprinting/.rss
                title: r/3Dprinting
              - url: https://www.reddit.com/r/fermentation/.rss
                title: r/fermentation
              - url: https://makezine.com/feed/
                title: Make Magazine

          - type: rss
            title: Deals & Outdoor
            style: horizontal-cards
            cache: 1h
            limit: 15
            collapse-after: 5
            feeds:
              - url: https://slickdeals.net/newsearch.php?mode=frontpage&searcharea=deals&searchin=first&rss=1
                title: Slickdeals
              - url: https://www.reddit.com/r/deals/.rss
                title: r/deals
              - url: https://www.reddit.com/r/frugalmalefashion/.rss
                title: r/frugalmalefashion
              - url: https://gearjunkie.com/feed
                title: Gear Junkie

```

Omit any feed whose URL failed verification in Task 2.

- [ ] **Run syntax check**

```bash
task syntax
```

Expected: no errors

---

### Task 5: Add Reddit group and YouTube to center column

Continue the center column with the Reddit group widget and the YouTube video grid.

- [ ] **Append to the center column block (after the last RSS widget, before the closing of the full column)**

```yaml
          - type: group
            cache: 30m
            widgets:
              - type: reddit
                subreddit: technology
                show-thumbnails: true
              - type: reddit
                subreddit: selfhosted
                show-thumbnails: true

          - type: videos
            style: grid-cards
            cache: 1h
            collapse-after-rows: 3
            channels:
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

- [ ] **Run syntax check**

```bash
task syntax
```

Expected: no errors

---

### Task 6: Rewrite right column

Replace the right (small) column. Weather is gone (moved to left). Releases is removed. Markets stays. Parenting/Health RSS is added.

- [ ] **Replace the right column block (from the second `- size: small` to just before `- name: Infrastructure`)**

Replace with:

```yaml
      - size: small
        widgets:
          - type: markets
            markets:
              - symbol: SPY
                name: S&P 500
              - symbol: BTC-USD
                name: Bitcoin
              - symbol: NVDA
                name: NVIDIA
              - symbol: AAPL
                name: Apple
              - symbol: MSFT
                name: Microsoft

          - type: rss
            title: Parenting & Health
            style: vertical-list
            cache: 12h
            limit: 15
            collapse-after: 5
            feeds:
              - url: https://www.fatherly.com/feed/
                title: Fatherly
              - url: https://www.thekitchn.com/main.rss
                title: The Kitchn
              - url: https://www.reddit.com/r/Parenting/.rss
                title: r/Parenting

```

Omit Mayo Clinic if its URL failed in Task 2.

- [ ] **Confirm the Infrastructure page block starting at `- name: Infrastructure` is untouched**

---

### Task 7: Full validation

- [ ] **Run syntax check**

```bash
task syntax
```

Expected: `playbook: main.yml` with no errors

- [ ] **Run lint**

```bash
task lint
```

Expected: no violations

- [ ] **Run dry-run for glance only**

```bash
doppler run -- ansible-playbook main.yml --limit glance --check
```

Expected: tasks show as changed/ok with no failures. The template task will show `changed` (expected — content changed).

---

### Task 8: Commit and ship

- [ ] **Stage the template**

```bash
git add roles/glance/templates/glance.yml.j2
```

- [ ] **Commit**

```bash
git commit -m "feat: redesign Glance home page as curated content aggregator"
```

- [ ] **Run `/ship` to push and open PR against dev**
