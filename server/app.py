import os
import json
import requests
from flask import Flask, jsonify, request
from flask_cors import CORS
from howlongtobeatpy import HowLongToBeat, HowLongToBeatEntry

app = Flask(__name__)
CORS(app)

_MAX_QUERY_LEN = 100
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


@app.route('/search')
def search():
    q = request.args.get('q', '').strip()[:_MAX_QUERY_LEN]
    limit = min(int(request.args.get('limit', 10)), 20)
    if not q:
        return jsonify([])

    try:
        results = HowLongToBeat().search(q)
    except Exception:
        return jsonify([])

    if not results:
        return jsonify([])

    return jsonify([_entry_to_dict(r) for r in results[:limit]])


@app.route('/lookup')
def lookup():
    """Returns the best match above a similarity threshold, or null."""
    q = request.args.get('q', '').strip()[:_MAX_QUERY_LEN]
    if not q:
        return jsonify(None)

    try:
        results = HowLongToBeat().search(q)
    except Exception:
        return jsonify(None)

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
