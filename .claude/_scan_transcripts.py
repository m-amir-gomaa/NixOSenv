#!/usr/bin/env python3
import json, os, re
from collections import Counter

proj_dir = os.path.expanduser("~/.claude/projects")
all_transcripts = []
for root, dirs, files in os.walk(proj_dir):
    for f in files:
        if f.endswith(".jsonl"):
            path = os.path.join(root, f)
            all_transcripts.append((os.path.getmtime(path), path))
all_transcripts.sort(reverse=True)
recent = [p for _, p in all_transcripts[:50]]

bash_counter = Counter()
mcp_counter = Counter()

# Commands that are auto-allowed at tool level - skip entirely
AUTO_ALLOWED_CMDS = {
    "cal", "uptime", "cat", "head", "tail", "wc", "stat", "strings",
    "hexdump", "od", "nl", "id", "uname", "free", "df", "du", "locale",
    "groups", "nproc", "basename", "dirname", "realpath", "cut", "paste",
    "tr", "column", "tac", "rev", "fold", "expand", "unexpand", "fmt",
    "comm", "cmp", "numfmt", "readlink", "diff", "true", "false", "sleep",
    "which", "type", "expr", "seq", "tsort", "pr", "echo", "ls", "cd",
    "pwd", "whoami", "alias", "sort", "man", "help", "netstat", "ps",
    "base64", "date", "hostname", "lsof", "pgrep", "tput", "ss", "fd",
    "fdfind", "aki", "rg", "jq", "uniq", "history", "arch", "ifconfig",
    "pyright", "printf", "test", "xargs", "file", "sha256sum", "sha1sum",
    "md5sum", "tree", "env", "printenv", "grep", "egrep", "fgrep",
    "sha256sum", "sha1sum", "md5sum"
}

GIT_SUB = {
    "status", "log", "diff", "show", "blame", "branch", "tag", "remote",
    "ls-files", "ls-remote", "rev-parse", "describe", "stash", "reflog",
    "shortlog", "cat-file", "for-each-ref", "worktree", "config",
}

GH_SUB = {
    "pr", "issue", "run", "workflow", "repo", "release", "auth",
}

DOCKER_SUB = {"ps", "images", "logs", "inspect"}

for path in recent:
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except:
                    continue
                if obj.get("type") != "assistant":
                    continue
                content = obj.get("message", {}).get("content", [])
                if isinstance(content, str):
                    continue
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") != "tool_use":
                        continue
                    tool_name = block.get("name", "")
                    inp = block.get("input", {})
                    if tool_name == "Bash":
                        cmd = inp.get("command", "")
                        if not cmd.strip():
                            continue
                        cleaned = cmd.strip()
                        # Handle sudo prefix
                        if cleaned.startswith("sudo "):
                            cleaned = cleaned[5:].strip()
                        # Handle timeouts
                        if cleaned.startswith("timeout "):
                            parts = cleaned.split()
                            if len(parts) >= 3:
                                cleaned = " ".join(parts[2:])
                        # Take first command before pipes, &&, ;, ||
                        first = cleaned.split("|")[0].strip()
                        for sep in ["&&", ";", "||"]:
                            if sep in first:
                                first = first.split(sep)[0].strip()
                        tokens = first.split()
                        if not tokens:
                            continue

                        # Auto-allow check
                        if tokens[0] in AUTO_ALLOWED_CMDS:
                            continue

                        # Build key
                        cmd0 = tokens[0]
                        if cmd0 in ("git",):
                            if len(tokens) >= 2 and tokens[1] in GIT_SUB:
                                key = f"git {tokens[1]}"
                            else:
                                continue  # skip mutations or unknown
                        elif cmd0 in ("gh",):
                            if len(tokens) >= 2:
                                key = f"gh {tokens[1]}"
                            else:
                                key = "gh"
                        elif cmd0 == "docker":
                            if len(tokens) >= 2 and tokens[1] in DOCKER_SUB:
                                key = "docker " + tokens[1]
                            else:
                                continue
                        elif cmd0 == "nix":
                            if len(tokens) >= 2:
                                key = "nix " + tokens[1]
                            else:
                                continue
                        elif cmd0 == "kubectl":
                            if len(tokens) >= 2 and tokens[1] in ("get", "describe"):
                                key = "kubectl " + tokens[1]
                            else:
                                continue
                        elif cmd0 == "npx":
                            if len(tokens) >= 2:
                                key = "npx " + tokens[1]
                            else:
                                continue
                        elif cmd0 == "python3":
                            if len(tokens) >= 2 and not tokens[1].startswith("-"):
                                # Script invocation
                                key = "python3"
                            else:
                                continue
                        else:
                            # Generic read-only candidate check
                            if cmd0 in AUTO_ALLOWED_CMDS:
                                continue
                            key = cmd0

                        bash_counter[key] += 1

                    elif tool_name.startswith("mcp__"):
                        mcp_counter[tool_name] += 1

print("=== BASH COMMANDS (read-only candidates, auto-allowed skipped) ===")
for item, count in bash_counter.most_common(50):
    print(f"{count:4d}  {item}")

print("\n=== MCP TOOLS ===")
for item, count in mcp_counter.most_common(50):
    print(f"{count:4d}  {item}")
