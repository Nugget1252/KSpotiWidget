import os
import sys
import json
import re
import unicodedata
import subprocess
REQUIRED_PACKAGES = ["flask", "deep_translator", "cutlet", "pykakasi", "cyrtranslit"]

for pkg in REQUIRED_PACKAGES:
    try:
        __import__(pkg)
    except ImportError:
        print(f"Auto-installing missing dependency: {pkg}...")
        try:
            subprocess.run([sys.executable, "-m", "pip", "install", pkg, "--break-system-packages"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            try:
                subprocess.run([sys.executable, "-m", "pip", "install", pkg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass

from flask import Flask, request, jsonify

kakasi_engine = None
katsu = None

try:
    import pykakasi
    kks = pykakasi.kakasi()
    kakasi_engine = kks
    print("pykakasi (Japanese Romaji Engine) loaded successfully.")
except Exception as e:
    print(f"pykakasi not found: {e}")

try:
    import cutlet
    katsu = cutlet.Cutlet()
    katsu.use_foreign_spelling = False
    print("Cutlet (Japanese Romaji Engine) loaded successfully.")
except Exception as e:
    katsu = None
    print(f"Cutlet failed to load: {e}. Japanese Romaji will fall back to pykakasi/original text.")

try:
    from deep_translator import GoogleTranslator
    print("Deep Translator (English Engine) loaded successfully.")
except Exception as e:
    GoogleTranslator = None
    print(f"Deep Translator failed to load: {e}. English conversion will fall back to original text.")

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

def transliterate_cyrillic(text):
    if not text:
        return ""

    # Strip Russian stress accents (e.g., а́ -> a)
    normalized = unicodedata.normalize('NFD', text)
    clean_text = "".join([c for c in normalized if unicodedata.category(c) != 'Mn'])

    try:
        import cyrtranslit
        return cyrtranslit.to_latin(clean_text, 'ru')
    except Exception:
        pass

    res = []
    for char in clean_text:
        res.append(CYRILLIC_MAP.get(char, char))
    return "".join(res)

def convert_to_romaji(text):
    if not text or not text.strip():
        return ""

    if katsu:
        try:
            converted = katsu.romaji(text)
            if converted and converted.strip() and converted != text:
                return converted
        except Exception as e:
            print(f"Cutlet Error on '{text}': {e}", file=sys.stderr)

    if kakasi_engine:
        try:
            res = kakasi_engine.convert(text)
            converted = " ".join([item['hepburn'] for item in res if item.get('hepburn')])
            if converted and converted.strip():
                return converted
        except Exception as e:
            print(f"pykakasi Error on '{text}': {e}", file=sys.stderr)

    return text

def translate_english_batch(lines_list):
    if not lines_list or not GoogleTranslator:
        return lines_list
    try:
        combined = "\n".join(lines_list)
        translator = GoogleTranslator(source='auto', target='en')
        translated = translator.translate(combined)
        result = translated.split("\n")
        if len(result) == len(lines_list):
            return result
        else:
            res = []
            for line in lines_list:
                if not line.strip():
                    res.append("")
                else:
                    try:
                        res.append(translator.translate(line))
                    except Exception:
                        res.append(line)
            return res
    except Exception as e:
        print(f" English Batch Translation Error: {e}", file=sys.stderr)
        return lines_list

def is_valid_translation(lyrics_list, mode):
    if not lyrics_list or not isinstance(lyrics_list, list):
        return False
    combined = " ".join([l.get('text', '') for l in lyrics_list if isinstance(l, dict)])
    if not combined.strip():
        return False
    if mode in ["romaji", "translit"]:
        if re.search(r'[\u3040-\u309f\u30a0-\u30ff\u0400-\u04ff]', combined):
            return False
    return True

def detect_script(lyrics_list, track_str=""):
    combined = track_str + " " + " ".join([line.get('text', '') for line in lyrics_list if isinstance(line, dict)])
    if re.search(r'[\u0400-\u04ff]', combined):
        return 'cyrillic'
    elif re.search(r'[\u3040-\u309f\u30a0-\u30ff\u4e00-\u9faf]', combined):
        return 'japanese'
    return 'latin'

app = Flask(__name__)

HAVE_SQLITE = False
try:
    import sqlite3
    HAVE_SQLITE = True
except ImportError:
    print("'sqlite3' module not available in this Python build. Using JSON file cache fallback.")

CACHE_FILE_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lyrics_cache.json")
DB_FILE_SQLITE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lyrics_cache.db")

def init_db():
    if HAVE_SQLITE:
        try:
            conn = sqlite3.connect(DB_FILE_SQLITE)
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS lyrics_cache (
                    track_artist TEXT,
                    mode TEXT,
                    lyrics_json TEXT,
                    PRIMARY KEY (track_artist, mode)
                )
            ''')
            conn.commit()
            conn.close()
            print(f"SQLite DB initialized at: {DB_FILE_SQLITE}")
            return
        except Exception as e:
            print(f"SQLite Init Failed: {e}. Falling back to JSON file cache.")

    if not os.path.exists(CACHE_FILE_JSON):
        try:
            with open(CACHE_FILE_JSON, 'w', encoding='utf-8') as f:
                json.dump({}, f)
        except Exception:
            pass
    print(f"JSON File Cache initialized at: {CACHE_FILE_JSON}")

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
            if row:
                return json.loads(row[0])
        except Exception as e:
            print(f"DB Read Error: {e}", file=sys.stderr)

    try:
        if os.path.exists(CACHE_FILE_JSON):
            with open(CACHE_FILE_JSON, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get(cache_key)
    except Exception as e:
        print(f"Cache Read Error: {e}", file=sys.stderr)
    return None

def db_save_lyrics(track_artist, mode, lyrics_list):
    cache_key = f"{track_artist}|||{mode}"
    if HAVE_SQLITE:
        try:
            conn = sqlite3.connect(DB_FILE_SQLITE)
            cursor = conn.cursor()
            cursor.execute(
                "INSERT OR REPLACE INTO lyrics_cache (track_artist, mode, lyrics_json) VALUES (?, ?, ?)",
                (track_artist, mode, json.dumps(lyrics_list, ensure_ascii=False))
            )
            conn.commit()
            conn.close()
            return
        except Exception as e:
            print(f"DB Write Error: {e}", file=sys.stderr)

    try:
        data = {}
        if os.path.exists(CACHE_FILE_JSON):
            with open(CACHE_FILE_JSON, 'r', encoding='utf-8') as f:
                data = json.load(f)
        data[cache_key] = lyrics_list
        with open(CACHE_FILE_JSON, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"Cache Write Error: {e}", file=sys.stderr)


@app.route('/position', methods=['GET'])
def get_position():
    position_ms = 0
    try:
        cmd = [
            "dbus-send", "--print-reply",
            "--dest=org.mpris.MediaPlayer2.spotify",
            "/org/mpris/MediaPlayer2",
            "org.freedesktop.DBus.Properties.Get",
            "string:org.mpris.MediaPlayer2.Player",
            "string:Position"
        ]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=1)
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "int64" in line:
                    position_ms = int(line.split()[-1]) // 1000
                    return jsonify({"position": position_ms, "status": "online"})

        res = subprocess.run(["playerctl", "-p", "spotify", "position"], stdout=subprocess.PIPE, text=True, timeout=1)
        if res.returncode == 0:
            position_ms = int(float(res.stdout.strip()) * 1000)
    except Exception:
        pass

    return jsonify({"position": position_ms, "status": "online"})


@app.route('/convert', methods=['POST'])
def convert():
    try:
        data = request.get_json() or {}
        incoming_lyrics = data.get('lyrics', [])
        mode = data.get('mode', 'romaji')
        track = data.get('track', 'Unknown Track')
        artist = data.get('artist', 'Unknown Artist')

        cache_key = f"{track}|||{artist}"

        valid_incoming = [
            l for l in incoming_lyrics
            if isinstance(l, dict) and l.get('text') and not l['text'].startswith("Searching") and not l['text'].startswith("Translating")
        ]

        base_lyrics = db_get_lyrics(cache_key, "kanji")
        if valid_incoming and (not base_lyrics or len(base_lyrics) < len(valid_incoming)):
            db_save_lyrics(cache_key, "kanji", valid_incoming)
            base_lyrics = valid_incoming

        if not base_lyrics:
            base_lyrics = valid_incoming if valid_incoming else incoming_lyrics

        script = detect_script(base_lyrics or incoming_lyrics, f"{track} {artist}")

        if script == 'cyrillic' and mode == 'romaji':
            mode = 'translit'

        print(f"[REQUEST] Track: '{track}' | Mode: '{mode}' | Script: '{script}' | Lines: {len(base_lyrics)}")

        cached_mode = db_get_lyrics(cache_key, mode)
        if cached_mode and base_lyrics and len(cached_mode) == len(base_lyrics):
            if is_valid_translation(cached_mode, mode):
                print(f"[STORAGE HIT] Serving '{mode}' ({script}) for: {cache_key}")
                if cached_mode and len(cached_mode) > 0:
                    print(f"   ↳ Sample: {cached_mode[0].get('text')}")
                return jsonify({"lyrics": cached_mode, "script": script})
            else:
                print(f"[PURGING STALE CACHE] Re-translating '{mode}' for: {cache_key}")

        if not base_lyrics or len(base_lyrics) == 0:
            return jsonify({"lyrics": [{"time": 0, "text": f"No lyrics found for {track}."}], "script": script})

        print(f"[TRANSLATING] Processing {len(base_lyrics)} lines -> '{mode}' [{script}] for: {cache_key}")

        processed_lyrics = []

        if mode == "english":
            texts = [l.get('text', '') for l in base_lyrics]
            translated_texts = translate_english_batch(texts)
            for i, line in enumerate(base_lyrics):
                t_text = translated_texts[i] if i < len(translated_texts) else line.get('text', '')
                processed_lyrics.append({"time": line.get('time', 0), "text": t_text})

        elif mode == "translit" or script == "cyrillic":
            for line in base_lyrics:
                orig = line.get('text', '')
                processed_lyrics.append({"time": line.get('time', 0), "text": transliterate_cyrillic(orig)})

        elif mode == "romaji":
            for line in base_lyrics:
                orig = line.get('text', '')
                processed_lyrics.append({"time": line.get('time', 0), "text": convert_to_romaji(orig)})

        else:
            processed_lyrics = base_lyrics

        if processed_lyrics and len(processed_lyrics) > 0:
            print(f"[PROCESSED] '{base_lyrics[0].get('text')}'  '{processed_lyrics[0].get('text')}'")

        if is_valid_translation(processed_lyrics, mode) or mode == "kanji":
            db_save_lyrics(cache_key, mode, processed_lyrics)

        return jsonify({"lyrics": processed_lyrics, "script": script})

    except Exception as e:
        print(f" SERVER ERROR: {str(e)}", file=sys.stderr)
        return jsonify({"lyrics": [{"time": 0, "text": f"Server Error: {str(e)}"}], "script": "latin"}), 500


if __name__ == '__main__':
    print("Starting storage-backed translation engine on http://127.0.0.1:28481")
    app.run(host='127.0.0.1', port=28481, debug=False)
