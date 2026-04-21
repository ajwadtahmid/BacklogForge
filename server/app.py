from flask import Flask, jsonify, request
from howlongtobeatpy import HowLongToBeat, HowLongToBeatEntry

app = Flask(__name__)

_MAX_QUERY_LEN = 100


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
