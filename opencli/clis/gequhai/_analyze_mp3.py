"""Analyze MP3 file and output metadata as JSON."""
import sys
import os
import json

filepath = sys.argv[1] if len(sys.argv) > 1 else ''
if not filepath or not os.path.exists(filepath):
    print(json.dumps({"error": "File not found"}))
    sys.exit(1)

try:
    from mutagen.mp3 import MP3
    audio = MP3(filepath)
    info = audio.info
    size = os.path.getsize(filepath)
    
    result = {
        "title": str(audio.get("TIT2", "")) or os.path.basename(filepath).replace(".mp3", ""),
        "artist": str(audio.get("TPE1", "")) or "Unknown",
        "album": str(audio.get("TALB", "")) or "",
        "duration_sec": round(info.length),
        "duration": f"{round(info.length)}s ({round(info.length/60, 1)}min)",
        "bitrate": f"{info.bitrate // 1000}kbps",
        "sample_rate": f"{info.sample_rate}Hz",
        "channels": "stereo" if info.channels == 2 else "mono",
        "file_size": f"{size / 1024 / 1024:.2f} MB",
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
except ImportError:
    size = os.path.getsize(filepath)
    print(json.dumps({
        "file_size": f"{size / 1024 / 1024:.2f} MB",
        "note": "Install mutagen for detailed analysis: pip install mutagen"
    }))
except Exception as e:
    print(json.dumps({"error": str(e)}))
