---
allowed-tools: Bash, Read
description: List recent Claude Code sessions for this project
---

## Sessions for this project

!`ls -lt ~/.claude/projects/-home-qwerty-NixOSenv/*.jsonl 2>/dev/null | head -15 | while read line; do f=$(echo "$line" | awk '{print $NF}'); uuid=$(basename "$f" .jsonl); size=$(wc -c < "$f"); date=$(echo "$line" | awk '{print $6, $7, $8}'); first=$(head -1 "$f" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',{}).get('content',[''])[0] if isinstance(d.get('message',{}).get('content'),list) else str(d.get('message',{}).get('content',''))[:80])" 2>/dev/null || echo "?"); echo "$uuid | $date | ${size}B | $first"; done`

## How to resume

- `claude --resume <uuid>` — resume a specific session
- `claude --continue` — resume the most recent session
- `claude --resume` — open interactive picker

To resume one of these, tell me the UUID or the topic you remember.
