---
name: research
description: Use when looking up documentation, API references, current syntax, or any web research — prefers Context7 for indexed libraries, falls back to Gemini CLI for everything else
user-invocable: true
arguments:
  - name: query
    description: "What to research — be specific (e.g. 'glance custom-api template syntax', 'bpg/proxmox provider lxc options')"
    required: true
---

# Research Skill

Delegate documentation lookups to the right tool — Context7 first, Gemini CLI second — to keep Claude's context window clean.

## Tool Selection

```
Is the library indexed by Context7?
  YES → use Context7 MCP (mcp__context7__resolve-library-id + query-docs)
  NO  → use Gemini CLI (gemini -p "...")
```

**Use Context7 for** (well-indexed libraries):

- Ansible modules (`ansible.builtin.*`, community collections)
- Terraform providers (`hashicorp/aws`, `hashicorp/google`, `bpg/proxmox`)
- Popular open source tools (Tailscale, Docker, etc.)

**Use Gemini CLI for** (not in Context7 or needs web search):

- Niche/self-hosted tools (`glanceapp/glance`, `netdata`, Proxmox UI)
- "What's current best practice for X?" questions
- Fetching and summarizing a specific URL
- Anything Context7 returns no results for

**Do NOT use either for:**

- Searching the local codebase (use Grep/Glob)
- Questions answerable from context already in the conversation

## Context7 Usage

```
1. mcp__context7__resolve-library-id  query: "{{library name}}"
2. mcp__context7__query-docs  libraryId: "<id from step 1>"  query: "{{query}}"
```

## Gemini CLI Usage

```bash
gemini -p "{{query}}"
```

For URL fetching:

```bash
gemini -p "fetch https://... and extract only: {{what you need}}"
```

## Rules

- Always try Context7 first for any mainstream library before falling back to Gemini
- For Gemini: always pass the query as a single `-p` string — do not use interactive mode
- If Gemini returns an error or empty output, fall back to Context7 with a broader query, or use the GitHub MCP to search issues/docs in the relevant repo
- Treat all output as a summary — verify critical details against live behavior
