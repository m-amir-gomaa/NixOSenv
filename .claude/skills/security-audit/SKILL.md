---
name: security-audit
description: Security audit using nmap, ss, tcpdump, strace, lsof. Use when user asks for security scan, audit, or network diagnostics.
invoke: user
argument-hint: "[target|port|process]"
output: full
---

Run security audit on: $ARGUMENTS

Follow the `.claude/rules/security.md` toolkit exactly:

1. If target is a host/IP: `nmap -sS -p- <target>` — explain SYN/ACK/RST
2. If checking local: `ss -tulnp` — socket bindings, process→port
3. If traffic: `tcpdump -vvv -nn -i <iface> -c 100`
4. If process: `strace -c <command>` or `lsof -i -P -n`

For each finding: layer (packet/socket/syscall) + normal/suspicious + remediation.
