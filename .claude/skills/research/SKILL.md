---
name: research
description: Use when looking up documentation, API references, current syntax, or any web research — routes queries to Gemini CLI to save Claude context tokens
user-invocable: true
arguments:
  - name: query
    description: "What to research — be specific (e.g. 'glance custom-api template syntax', 'bpg/proxmox provider lxc options')"
    required: true
---

# Research Skill

Delegate web research and documentation lookups to Gemini CLI to keep Claude's context window clean.

## When to Use

Use this skill (or call `gemini -p` directly) for:
- Library/provider API docs (`bpg/proxmox`, `glanceapp/glance`, `ansible modules`)
- Current syntax for tools that change frequently (Terraform, Ansible, Glance widgets)
- "What options does X support?" questions
- Fetching and summarizing a specific URL

Do NOT use for:
- Searching the local codebase (use Grep/Glob)
- Questions answerable from context already in the conversation

## How to Call

```bash
gemini -p "{{query}}"
```

For URL fetching:
```bash
gemini -p "fetch https://... and summarize: {{query}}"
```

For structured extraction:
```bash
gemini -p "fetch https://... and extract only: the JSON schema / available options / template syntax for {{query}}"
```

## Rules

- Always pass the query as a single `-p` string — do not use interactive mode
- Pipe output through `head -100` if you only need a summary: `gemini -p "..." | head -100`
- If Gemini returns an error or empty output, fall back to `WebFetch` or `WebSearch`
- Treat Gemini output as a summary — verify critical details (e.g. exact field names) against live behavior
