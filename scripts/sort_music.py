import os
import re
import shutil

music_list_path = "/tmp/music_list.txt"
source_dir = "/home/qwerty/Music/new"
target_base_dir = "/home/qwerty/Music"

id_map = {}
title_map = {}

# Build maps from music_list.txt
if os.path.exists(music_list_path):
    with open(music_list_path, "r") as f:
        for line in f:
            line = line.strip()
            # Remove multiple leading characters if they are not part of the path
            while line and not line.startswith("/"):
                line = line[1:]
            
            if not line:
                continue
                
            full_path = line
            filename = os.path.basename(full_path)
            dirname = os.path.dirname(full_path)
            
            # Extract ID if present (handles both [ID] and [ID] at start)
            matches = re.findall(r"\[(\d+)\]", filename)
            for track_id in matches:
                id_map[track_id] = dirname
            
            # Use filename base (without extension) as key
            title = os.path.splitext(filename)[0]
            title_map[title] = dirname
            # Also map a version without the ID part for fuzzy matching
            title_no_id = re.sub(r"\[\d+\]", "", title).strip()
            if title_no_id:
                title_map[title_no_id] = dirname


print(f"Mapped {len(id_map)} IDs and {len(title_map)} titles.")

# Sort the files
for f in os.listdir(source_dir):
    if f.endswith((".mp3", ".m4a", ".wav", ".flac", ".mp4")):
        source_path = os.path.join(source_dir, f)
        filename_base, ext = os.path.splitext(f)
        
        target_dir = None
        
        # Try ID match
        match = re.search(r"\[(\d+)\]", filename_base)
        if match:
            track_id = match.group(1)
            if track_id in id_map:
                target_dir = id_map[track_id]
        
        # Try Title match
        if not target_dir:
            if filename_base in title_map:
                target_dir = title_map[filename_base]
            else:
                # Fuzzy match title (remove the ID part)
                title_no_id = re.sub(r"\s*\[\d+\]", "", filename_base).strip()
                if title_no_id in title_map:
                    target_dir = title_map[title_no_id]

        if target_dir:
            os.makedirs(target_dir, exist_ok=True)
            target_path = os.path.join(target_dir, f)
            print(f"Moving: {f} -> {target_dir}")
            shutil.move(source_path, target_path)
        else:
            print(f"No match for: {f}")
