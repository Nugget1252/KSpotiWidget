import os
import sys
import json
import re
import unicodedata
import subprocess
import requests
from concurrent.futures import ThreadPoolExecutor

REQUIRED_PACKAGES = ["flask", "deep_translator", "cutlet", "pykakasi", "cyrtranslit", "requests"]
if os.name == 'nt':
    REQUIRED_PACKAGES.append("winsdk")

for pkg in REQUIRED_PACKAGES:
    try:
        __import__(pkg)
    except ImportError:
        try:
            subprocess.run([sys.executable, "-m", "pip", "install", pkg, "--break-system-packages"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            try:
                subprocess.run([sys.executable, "-m", "pip", "install", pkg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception: pass

from flask import Flask, request, jsonify

app = Flask(__name__)

@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    return response

http_session = requests.Session()
http_session.headers.update({"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})

HAVE_WINRT = False
if os.name == 'nt':
    try:
        import winsdk.windows.media.control as wmc
        import winsdk.windows.storage.streams as streams
        import asyncio
        HAVE_WINRT = True
    except ImportError: pass

kakasi_engine = None
katsu = None

try:
    import pykakasi
    kakasi_engine = pykakasi.kakasi()
except Exception: pass

try:
    import cutlet
    katsu = cutlet.Cutlet()
    katsu.use_foreign_spelling = False
except Exception: pass

try:
    from deep_translator import GoogleTranslator
except Exception:
    GoogleTranslator = None

CYRILLIC_MAP = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo', 'ж': 'zh',
    'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o',
    'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts',
    'ч': 'ch', 'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo', 'Ж': 'Zh',
    'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M', 'Н': 'N', 'О': 'O',
    'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U', 'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts',
    'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch', 'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
    'і': 'i', 'І': 'I', 'ї': 'yi', 'Ї': 'Yi', 'є': 'ye', 'Є': 'Ye', 'ґ': 'g', 'Ґ': 'G',
    'ў': 'u', 'Ў': 'U', 'ђ': 'dj', 'Ђ': 'Dj', 'ј': 'j', 'Ј': 'J', 'љ': 'lj', 'Љ': 'Lj',
    'њ': 'nj', 'Њ': 'Nj', 'ћ': 'c', 'Ћ': 'C', 'џ': 'dz', 'Џ': 'Dz', 'ѕ': 'z', 'Ѕ': 'Z'
}

def fetch_lrclib_lyrics(track, artist):
    try:
        url = "https://lrclib.net/api/search"
        params = {"track_name": track, "artist_name": artist}
        resp = http_session.get(url, params=params, timeout=3.5)
        if resp.status_code == 200:
            results = resp.json()
            if isinstance(results, list) and len(results) > 0:
                synced_text = None
                for item in results:
                    if item.get("syncedLyrics"):
                        synced_text = item.get("syncedLyrics")
                        break
                if synced_text:
                    parsed_lyrics = []
                    lines = synced_text.split("\n")
                    for line in lines:
                        match = re.match(r'\[(\d+):(\d+\.\d+)\](.*)', line)
                        if match:
                            mins = int(match.group(1))
                            secs = float(match.group(2))
                            parsed_lyrics.append({"time": mins * 60 + secs, "text": match.group(3).strip()})
                    return parsed_lyrics
    except Exception: pass
    return []

def transliterate_cyrillic(text):
    if not text: return ""
    norm = unicodedata.normalize('NFD', text)
    clean = "".join([c for c in norm if unicodedata.category(c) != 'Mn'])
    try:
        import cyrtranslit
        return cyrtranslit.to_latin(clean, 'ru')
    except Exception: pass
    return "".join([CYRILLIC_MAP.get(c, c) for c in clean])

def convert_to_romaji(text):
    if not text or not text.strip(): return ""
    if katsu:
        try:
            res = katsu.romaji(text)
            if res and res.strip() and res != text: return res
        except Exception: pass
    if kakasi_engine:
        try:
            res = kakasi_engine.convert(text)
            conv = " ".join([item['hepburn'] for item in res if item.get('hepburn')])
            if conv and conv.strip(): return conv
        except Exception: pass
    return text

def translate_single_line_fast(line):
    raw = str(line).strip()
    if not raw or len(raw) == 0:
        return ""
    try:
        url = "https://translate.googleapis.com/translate_a/single"
        params = {
            "client": "gtx",
            "sl": "auto",
            "tl": "en",
            "dt": "t",
            "q": raw
        }
        res = http_session.get(url, params=params, timeout=2.5)
        if res.status_code == 200:
            data = res.json()
            if data and len(data) > 0 and data[0]:
                parts = [seg[0] for seg in data[0] if seg and len(seg) > 0 and isinstance(seg[0], str)]
                out = "".join(parts).strip()
                if out and "500 (Server Error)" not in out and "That's an error" not in out:
                    return out
    except Exception: pass

    if GoogleTranslator:
        try:
            out = GoogleTranslator(source='auto', target='en').translate(raw)
            if out and "500" not in out and "error" not in out.lower():
                return out
        except Exception: pass

    return raw

def translate_english_batch(lines_list):
    if not lines_list: return []
    texts = [l if isinstance(l, str) else str(l) for l in lines_list]
    with ThreadPoolExecutor(max_workers=8) as executor:
        return list(executor.map(translate_single_line_fast, texts))

def is_valid_translation(lyrics_list, mode, base_lyrics=None):
    if not lyrics_list or not isinstance(lyrics_list, list): return False
    combined = " ".join([l.get('text', '') for l in lyrics_list if isinstance(l, dict)])
    if not combined.strip(): return False

    if "500 (Server Error)" in combined or "That’s an error" in combined or "That's an error" in combined:
        return False

    if mode in ["romaji", "translit"]:
        if re.search(r'[\u3040-\u309f\u30a0-\u30ff\u0400-\u04ff]', combined): return False

    if mode == "english" and base_lyrics and len(base_lyrics) > 5:
        base_combined = " ".join([l.get('text', '') for l in base_lyrics if isinstance(l, dict)])
        if combined == base_combined and re.search(r'[^\x00-\x7F]', base_combined):
            return False

    return True

def detect_script(lyrics_list, track_str=""):
    combined = track_str + " " + " ".join([line.get('text', '') for line in lyrics_list if isinstance(line, dict)])
    if re.search(r'[\u0400-\u04ff]', combined): return 'cyrillic'
    elif re.search(r'[\u3040-\u309f\u30a0-\u30ff\u4e00-\u9faf]', combined): return 'japanese'
    return 'latin'

HAVE_SQLITE = False
try:
    import sqlite3
    HAVE_SQLITE = True
except ImportError: pass

CACHE_FILE_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lyrics_cache.json")
DB_FILE_SQLITE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lyrics_cache.db")

def init_db():
    if HAVE_SQLITE:
        try:
            conn = sqlite3.connect(DB_FILE_SQLITE)
            cursor = conn.cursor()
            cursor.execute('CREATE TABLE IF NOT EXISTS lyrics_cache (track_artist TEXT, mode TEXT, lyrics_json TEXT, PRIMARY KEY (track_artist, mode))')
            conn.commit()
            conn.close()
            return
        except Exception: pass
    if not os.path.exists(CACHE_FILE_JSON):
        try:
            with open(CACHE_FILE_JSON, 'w', encoding='utf-8') as f: json.dump({}, f)
        except Exception: pass

init_db()

def db_get_lyrics(track_artist, mode):
    cache_key = f"{track_artist}|||{mode}"
    if HAVE_SQLITE:
        try:
            conn = sqlite3.connect(DB_FILE_SQLITE)
            cursor = conn.cursor()
            cursor.execute("SELECT lyrics_json FROM lyrics_cache WHERE track_artist = ? AND mode = ?", (track_artist, mode))
            row = cursor.fetchone()
            conn.close()
            if row: return json.loads(row[0])
        except Exception: pass
    try:
        if os.path.exists(CACHE_FILE_JSON):
            with open(CACHE_FILE_JSON, 'r', encoding='utf-8') as f: return json.load(f).get(cache_key)
    except Exception: pass
    return None

def db_save_lyrics(track_artist, mode, lyrics_list):
    cache_key = f"{track_artist}|||{mode}"
    if HAVE_SQLITE:
        try:
            conn = sqlite3.connect(DB_FILE_SQLITE)
            cursor = conn.cursor()
            cursor.execute("INSERT OR REPLACE INTO lyrics_cache (track_artist, mode, lyrics_json) VALUES (?, ?, ?)", (track_artist, mode, json.dumps(lyrics_list, ensure_ascii=False)))
            conn.commit()
            conn.close()
            return
        except Exception: pass
    try:
        data = {}
        if os.path.exists(CACHE_FILE_JSON):
            with open(CACHE_FILE_JSON, 'r', encoding='utf-8') as f: data = json.load(f)
        data[cache_key] = lyrics_list
        with open(CACHE_FILE_JSON, 'w', encoding='utf-8') as f: json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception: pass

@app.route('/control', methods=['GET', 'POST', 'OPTIONS'])
def media_control():
    if request.method == 'OPTIONS': return jsonify({}), 200
    cmd = request.args.get('cmd', '')
    if os.name == 'posix':
        try:
            if cmd == 'playpause': subprocess.run(["playerctl", "-p", "spotify", "play-pause"], timeout=0.3)
            elif cmd == 'next': subprocess.run(["playerctl", "-p", "spotify", "next"], timeout=0.3)
            elif cmd == 'prev': subprocess.run(["playerctl", "-p", "spotify", "previous"], timeout=0.3)
            elif cmd == 'volume':
                delta = float(request.args.get('delta', '0.05'))
                sign = "+" if delta > 0 else "-"
                subprocess.run(["playerctl", "-p", "spotify", "volume", f"{abs(delta)}{sign}"], timeout=0.3)
            elif cmd == 'seek':
                sec = float(request.args.get('sec', '0'))
                subprocess.run(["playerctl", "-p", "spotify", "position", str(sec)], timeout=0.3)
        except Exception: pass
    return jsonify({"status": "ok"})

@app.route('/status', methods=['GET', 'OPTIONS'])
def get_status():
    if request.method == 'OPTIONS': return jsonify({}), 200
    info = {"track": "Spotify", "artist": "No song playing", "position": 0, "length": 1, "artUrl": "", "playing": False}

    if os.name == 'posix':
        try:
            out = subprocess.check_output(
                ["playerctl", "-p", "spotify", "metadata", "--format", "{{title}}|||{{artist}}|||{{position}}|||{{mpris:artUrl}}|||{{status}}|||{{mpris:length}}"],
                text=True, timeout=0.25
            ).strip()
            parts = out.split("|||")
            if len(parts) >= 5:
                info["track"] = parts[0]
                info["artist"] = parts[1]
                info["position"] = int(float(parts[2]) / 1000) if parts[2] else 0
                info["artUrl"] = parts[3]
                info["playing"] = (parts[4].lower() == "playing")
                info["length"] = int(float(parts[5]) / 1000) if (len(parts) >= 6 and parts[5]) else 1
        except Exception: pass

    elif os.name == 'nt' and HAVE_WINRT:
        try:
            async def get_win_media():
                mgr = await wmc.GlobalSystemMediaTransportControlsSessionManager.request_async()
                sess = mgr.get_current_session()
                if sess:
                    p = await sess.try_get_media_properties_async()
                    tl = sess.get_timeline_properties()
                    pb = sess.get_playback_info()
                    info["track"] = p.title or "Spotify"
                    info["artist"] = p.artist or "Unknown Artist"
                    info["position"] = int(tl.position.total_seconds() * 1000) if tl else 0
                    info["length"] = int(tl.end_time.total_seconds() * 1000) if (tl and tl.end_time.total_seconds() > 0) else 1
                    info["playing"] = (pb.playback_status == wmc.GlobalSystemMediaTransportControlsSessionPlaybackStatus.PLAYING) if pb else False
            asyncio.run(get_win_media())
        except Exception: pass

    return jsonify(info)

@app.route('/position', methods=['GET', 'OPTIONS'])
def get_position():
    if request.method == 'OPTIONS': return jsonify({}), 200
    return get_status()

@app.route('/convert', methods=['POST', 'OPTIONS'])
def convert():
    if request.method == 'OPTIONS': return jsonify({}), 200
    try:
        data = request.get_json() or {}
        incoming_lyrics = data.get('lyrics', [])
        mode = data.get('mode', 'romaji')
        track = data.get('track', 'Unknown Track')
        artist = data.get('artist', 'Unknown Artist')

        cache_key = f"{track}|||{artist}"
        valid_incoming = [l for l in incoming_lyrics if isinstance(l, dict) and l.get('text') and not l['text'].startswith("Searching") and not l['text'].startswith("Translating")]

        base_lyrics = db_get_lyrics(cache_key, "kanji")
        if valid_incoming and (not base_lyrics or len(base_lyrics) < len(valid_incoming)):
            db_save_lyrics(cache_key, "kanji", valid_incoming)
            base_lyrics = valid_incoming

        if not base_lyrics or len(base_lyrics) == 0:
            fetched = fetch_lrclib_lyrics(track, artist)
            if fetched:
                db_save_lyrics(cache_key, "kanji", fetched)
                base_lyrics = fetched

        if not base_lyrics: base_lyrics = valid_incoming if valid_incoming else incoming_lyrics

        script = detect_script(base_lyrics or incoming_lyrics, f"{track} {artist}")
        if script == 'cyrillic' and mode == 'romaji': mode = 'translit'
        if script == 'japanese' and mode == 'translit': mode = 'romaji'

        cached_mode = db_get_lyrics(cache_key, mode)
        if cached_mode and base_lyrics and len(cached_mode) == len(base_lyrics):
            if is_valid_translation(cached_mode, mode, base_lyrics):
                return jsonify({"lyrics": cached_mode, "script": script})

        if not base_lyrics or len(base_lyrics) == 0:
            return jsonify({"lyrics": [{"time": 0, "text": f"No lyrics found for {track}."}], "script": script})

        processed_lyrics = []
        if mode == "english":
            texts = [l.get('text', '') for l in base_lyrics]
            translated_texts = translate_english_batch(texts)
            for i, line in enumerate(base_lyrics):
                t_text = translated_texts[i] if i < len(translated_texts) else line.get('text', '')
                processed_lyrics.append({"time": line.get('time', 0), "text": t_text})

        elif mode == "translit" or script == "cyrillic":
            for line in base_lyrics:
                processed_lyrics.append({"time": line.get('time', 0), "text": transliterate_cyrillic(line.get('text', ''))})

        elif mode == "romaji":
            for line in base_lyrics:
                processed_lyrics.append({"time": line.get('time', 0), "text": convert_to_romaji(line.get('text', ''))})

        else: processed_lyrics = base_lyrics

        if is_valid_translation(processed_lyrics, mode, base_lyrics) or mode == "kanji":
            db_save_lyrics(cache_key, mode, processed_lyrics)

        return jsonify({"lyrics": processed_lyrics, "script": script})

    except Exception as e:
        return jsonify({"lyrics": [{"time": 0, "text": f"Server Error: {str(e)}"}], "script": "latin"}), 500

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=28481, debug=False)
