import os
import re
import json
import requests
import concurrent.futures
from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from howlongtobeatpy import HowLongToBeat, HowLongToBeatEntry

app = Flask(__name__)
CORS(app, origins=["https://backlogforge.onrender.com"])

limiter = Limiter(get_remote_address, app=app, default_limits=[])

_MAX_QUERY_LEN = 100
_HLTB_TIMEOUT = 10          # seconds before giving up on a HowLongToBeat request
_STEAM_API_KEY = os.getenv('STEAM_API_KEY', '')
_STEAM_BASE = 'https://api.steampowered.com'


def _entry_to_dict(entry: HowLongToBeatEntry) -> dict:
    return {
        'id': entry.game_id,
        'name': entry.game_name,
        'image_url': entry.game_image_url,
        'essential_hours': entry.main_story if entry.main_story > 0 else None,
        'extended_hours': entry.main_extra if entry.main_extra > 0 else None,
        'completionist_hours': entry.completionist if entry.completionist > 0 else None,
    }


def _hltb_search(q: str):
    """Run HowLongToBeat().search() in a thread so we can apply a timeout.

    HowLongToBeat().search() is a blocking HTTP call with no built-in timeout.
    Wrapping it in a ThreadPoolExecutor lets us cancel via future.result(timeout=…)
    without leaving the main thread stuck indefinitely.
    """
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(HowLongToBeat().search, q)
        return future.result(timeout=_HLTB_TIMEOUT)


@app.route('/search')
@limiter.limit("10/minute")
def search():
    """
    Search HowLongToBeat by game title.
    Query parameters:
      - q:     Search query string (required)
      - limit: Maximum number of results to return (default 10, max 20)
    Returns a JSON array of matching game objects, or an error object on failure.
    """
    q = request.args.get('q', '').strip()[:_MAX_QUERY_LEN]
    limit = min(int(request.args.get('limit', 10)), 20)
    if not q:
        return jsonify([])

    try:
        results = _hltb_search(q)
    except concurrent.futures.TimeoutError:
        return jsonify({'error': 'search_timeout'}), 504
    except Exception:
        return jsonify({'error': 'search_failed'}), 502

    if not results:
        return jsonify([])

    return jsonify([_entry_to_dict(r) for r in results[:limit]])


@app.route('/lookup')
@limiter.limit("300/minute")
def lookup():
    """Returns the best match above a similarity threshold, or null."""
    q = request.args.get('q', '').strip()[:_MAX_QUERY_LEN]
    if not q:
        return jsonify(None)

    try:
        results = _hltb_search(q)
    except concurrent.futures.TimeoutError:
        return jsonify({'error': 'lookup_timeout'}), 504
    except Exception:
        return jsonify({'error': 'lookup_failed'}), 502

    if not results:
        return jsonify(None)

    best = max(results, key=lambda r: r.similarity)
    if best.similarity < 0.4:
        return jsonify(None)

    return jsonify(_entry_to_dict(best))


@app.route('/health')
def health():
    return jsonify({'status': 'ok'})


@app.route('/user/library')
@limiter.limit("5/minute")
def user_library():
    """
    Fetch owned games for a Steam user.
    Query parameters:
      - steam_id: The user's Steam ID (required)
    """
    if not _STEAM_API_KEY:
        return jsonify({'error': 'STEAM_API_KEY not configured'}), 500

    steam_id = request.args.get('steam_id', '').strip()
    if not steam_id:
        return jsonify({'error': 'steam_id required'}), 400
    if not re.match(r'^\d{17}$', steam_id):
        return jsonify({'error': 'invalid_steam_id'}), 400

    try:
        url = (
            f'{_STEAM_BASE}/IPlayerService/GetOwnedGames/v1/'
            f'?key={_STEAM_API_KEY}&steamid={steam_id}'
            f'&include_appinfo=true&include_played_free_games=true'
        )
        response = requests.get(url, timeout=15)
        if response.status_code != 200:
            return jsonify({'error': 'steam_api_error'}), 502

        data = response.json()
        games = data.get('response', {}).get('games')
        if games is None:
            return jsonify({'error': 'profile_private'}), 403

        return jsonify(games), 200

    except requests.Timeout:
        return jsonify({'error': 'steam_api_timeout'}), 504
    except Exception as e:
        return jsonify({'error': str(e)}), 500
