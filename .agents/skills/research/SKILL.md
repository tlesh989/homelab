---
name: research
description: Use when looking up documentation, API references, current syntax, or any web research — prefers Context7 for indexed libraries, falls back to web search for everything else
user-invocable: true
arguments:
  - name: query
    description: "What to research — be specific (e.g. 'glance custom-api template syntax', 'bpg/proxmox provider lxc options')"
    required: true
---

# Research Skill

Delegate documentation lookups to the right tool — Context7 first, web search second — to keep context clean.

## Tool Selection

```
Is the library indexed by Context7?
  YES → use Context7 MCP (mcp__context7__resolve-library-id + query-docs)
  NO  → use search_web or read_url_content
```

**Use Context7 for** (well-indexed libraries):

- Ansible modules (`ansible.builtin.*`, community collections)
- Terraform providers (`hashicorp/aws`, `hashicorp/google`, `bpg/proxmox`)
- Popular open source tools (Tailscale, Docker, etc.)

**Use search_web / read_url_content for** (not in Context7 or needs web search):

- Niche/self-hosted tools (`glanceapp/glance`, `netdata`, Proxmox UI)
- "What's current best practice for X?" questions
- Fetching and summarizing a specific URL
- Anything Context7 returns no results for

**Do NOT use either for:**

- Searching the local codebase (use Grep/Glob)
- Questions answerable from context already in the conversation

## Rules

- Always try Context7 first for any mainstream library before falling back to web search
- Treat all output as a summary — verify critical details against live behavior
