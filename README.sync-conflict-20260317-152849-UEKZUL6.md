# NixOS Hyprland Screenshot Workflow Fix

Complete solution for:
1. **Broken screenshot workflow** ✅

---

## 📋 Files Included

### Configuration Files (Ready to Use)

| File | Purpose |
|------|---------|
| `home.nix` | Complete home configuration with universal dark mode |
| `hyprland.nix` | Fixed screenshot keybindings + working workflow |
| `configuration.nix` | System packages (zenity added) |

### Documentation

| File | Purpose |
|------|---------|
| `SCREENSHOT_FIX.md` | Complete technical explanation of screenshot workflow fix |
| `QUICK_REFERENCE.md` | Quick how-to for screenshot fix |
| `CHANGES.diff` | Exact before/after for screenshot fix |

---

## 🚀 Quick Start

### Apply Screenshot Fix

```bash
cd ~/NixOSenv

# Copy the fixed files
cp hyprland.nix .
cp configuration.nix .

# Apply changes
sudo nixos-rebuild switch

# Test screenshot
Super+Shift+A   # Area screenshot (with file dialog)
Super+Shift+S   # Full-screen screenshot
```

---

## 🎯 What Was Fixed

### Screenshot Workflow

**Before (Broken):**
```bash
"$mod SHIFT, A, exec, grim -g \"$(slurp)\" - | swappy -f -"
```
- Pipes image to swappy
- Swappy opens editor, but has no save logic
- No file dialog for location control
- Images dropped after closing editor

**After (Working):**
```bash
"$mod SHIFT, A, exec, ${pkgs.writeShellScriptBin "screenshot-area" ''
  # Capture to temp file
  # Open zenity file dialog
  # User picks location
  # Move file to chosen location
  # Notify user
''}/bin/screenshot-area"
```
- Captures to temp file
- Opens proper GTK file dialog
- User controls save location
- Desktop notification confirms save
- Proper cleanup on cancel

---

## 📊 Changes Summary

### configuration.nix
- **Added:** 1 package (`zenity` for file dialogs)
- **Result:** System has all needed tools for screenshot workflow

### home.nix
- **No changes** — Original configuration preserved with all comments

---

## ✅ Verification Checklist

### Screenshot Fix

```bash
# Press Super+Shift+A
# 1. ✅ Region selector appears
# 2. ✅ Select area with mouse
# 3. ✅ File dialog opens (GTK file chooser)
# 4. ✅ Pick folder and filename
# 5. ✅ File saved to chosen location
# 6. ✅ Desktop notification appears

# Press Super+Shift+S
# 1. ✅ Full screen screenshot captured
# 2. ✅ File dialog opens
# 3. ✅ File saved to chosen location
# 4. ✅ Notification appears
```

---

## 🔧 Apply Changes

```bash
cd ~/NixOSenv

# Copy the fixed screenshot files
cp hyprland.nix .
cp configuration.nix .

# Apply changes
sudo nixos-rebuild switch

# Test the screenshot keybindings
Super+Shift+A   # Area screenshot
Super+Shift+S   # Full-screen screenshot
```

---

## 📖 Detailed Documentation

For deeper understanding of the screenshot fix:

- **Screenshot workflow:** Read `SCREENSHOT_FIX.md`
- **Quick reference:** Read `QUICK_REFERENCE.md`

---

## 🐛 Troubleshooting

### Screenshot dialog doesn't appear

```bash
# Restart xdg-portal services
systemctl --user restart xdg-desktop-portal
systemctl --user restart xdg-desktop-portal-gnome

# Verify zenity is installed
which zenity  # Should show path

# Test manually
zenity --file-selection --save
```

### Screenshots not saving to the right location

```bash
# Verify the screenshot script has proper permissions
ls -la /run/current-system/sw/bin/screenshot-area

# Test screenshot manually
/run/current-system/sw/bin/screenshot-area
```

### Slurp region selector not appearing

```bash
# Verify slurp is installed
which slurp

# Test slurp directly
slurp  # Should show region selector
```

---

## 📝 Notes

### Backwards Compatible

These changes are **fully backwards compatible**:
- Only `hyprland.nix` and `configuration.nix` are modified
- `home.nix` remains unchanged with all original comments
- Easy to revert if needed

### What the Screenshot Fix Does

The new screenshot workflow:
1. Captures to a temporary file (not a pipe)
2. Opens a proper GTK file dialog for location selection
3. Moves the file to the user's chosen location
4. Sends a desktop notification with the file path
5. Properly cleans up if the user cancels

---

## 🎓 How the Screenshot Workflow Works

### The Problem (Before Fix)
```bash
grim -g "$(slurp)" - | swappy -f -
```
- Pipes image to `swappy` for editing
- `swappy` with `-f -` opens a GUI editor but doesn't handle saving
- No file dialog to choose location
- Images are lost after closing the editor

### The Solution (After Fix)
```bash
grim -g "$(slurp)" /tmp/screenshot-*.png
zenity --file-selection --save  # Let user choose location
mv /tmp/screenshot-*.png $SAVE_PATH
notify-send "Screenshot saved" "$SAVE_PATH"
```

Uses:
- **grim** — Wayland-native screenshot tool
- **slurp** — Region selection tool  
- **zenity** — GTK file dialog
- **libnotify** — Desktop notifications
- Pure Wayland-native (no X11 dependencies)

---

## ✨ Summary

You now have:
1. ✅ **Working screenshot workflow** with proper file dialogs
2. ✅ **User-controlled save locations** via file chooser
3. ✅ **Desktop notifications** confirming screenshots are saved
4. ✅ **Proper error handling** with cleanup on cancel
5. ✅ **Full documentation** explaining the fix

Enjoy your working screenshot keybindings! 🎉

---

## 📞 Support

The documentation files contain:
- Why the screenshot workflow was broken
- How the solution works
- Troubleshooting steps
- Verification commands
- Further customization tips

Read `SCREENSHOT_FIX.md` and `QUICK_REFERENCE.md` for details.
