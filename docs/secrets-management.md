*Next: [System Overview](./system-overview.md)*

---

# Secrets Management in NixOS

This environment uses `age` encryption to securely manage API keys and credentials while still allowing them to be tracked declaratively in the Git repository.

## The Architecture
Because NixOS stores the entire system configuration in the world-readable `/nix/store`, embedding raw API keys inside files like `home.nix` or `configuration.nix` exposes them. 

To solve this, we track an encrypted vault block inside Git but decrypt it locally right before rebuilding.

**Core Files:**
1. `secrets.nix.age` - The **encrypted** vault containing the raw keys. This file is safely checked into Git.
2. `~/.age-key.txt` - Your private, **untracked** encryption/decryption key.
3. `secrets.nix` - The **decrypted**, plaintext vault. This file is in `.gitignore` and must never be committed.

## 🛠️ Modifying Secrets

If you need to add, update, or remove an API key (e.g., your Anthropic API Key), follow this robust sequence:

### 1. Decrypt the Vault
```bash
cd ~/NixOSenv
age -d -i ~/.age-key.txt secrets.nix.age > secrets.nix
```

### 2. Edit the Plaintext
Open `secrets.nix` in your text editor (e.g., Neovim) and modify your tokens.
```bash
nvim secrets.nix
```
*Note: Make sure your `home.nix` aliases correctly map the variables you declare here.*

### 3. Re-Encrypt
Once edits are complete, you must re-encrypt the file using your public key so the changes can be safely committed to GitHub:
```bash
# Get your public key from the identity file
age-keygen -y ~/.age-key.txt

# Overwrite the encrypted vault (Replace PUBLIC_KEY below with the string from the command above)
age -r public-key1... secrets.nix > secrets.nix.age
```

### 4. Build the System
You can now build using the built-in `nr` alias, which handles the decryption step automatically before invoking the flake builder:
```bash
nr
```

> [!WARNING]
> Ensure that `secrets.nix` is strictly ignored by your Git client. The `nr` alias operates by keeping `secrets.nix` completely untracked, avoiding dangerous leaks.

---

*Next: [System Overview](./system-overview.md)*
