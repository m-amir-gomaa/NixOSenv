#!/usr/bin/env python3
import yaml, os, subprocess

model_yaml = os.path.expanduser("~/.config/sovereign/models.yaml")
if not os.path.exists(model_yaml):
    print("❌ models.yaml not found.")
    exit(1)

with open(model_yaml, 'r') as f:
    data = yaml.safe_load(f)
    for entry in data.get('providers', []):
        alias = entry.get('alias')
        model_id = entry.get('id')
        print(f"🔗 Registering {alias} ({model_id}) in RuFlo Swarm...")
        subprocess.run(["ruflo", "providers", "add", "--name", alias, "--model", model_id], capture_output=True)

print("✅ RuFlo Swarm synchronized with Sovereign Registry.")
