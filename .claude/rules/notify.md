# Notify

## TTS Notifications

- **Approval Strategy**: Before commands that trigger approval (e.g. file writes), run the TTS command as an **isolated tool call**. After it completes, run the actual command in your next response. Do NOT combine them.
- **Completion**: Run TTS after finishing a task.
- **Commands**: `say "<msg>"` (macOS) | default OS TTS for others.
- **Messages**: `"Task complete"`, `"Claude needs your attention"`, `"Something went wrong"`
