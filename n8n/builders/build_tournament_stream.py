"""Builds the tournament live-stream link workflow (app: tournament page → About → YouTube live link).

  python3 build_tournament_stream.py   → writes ../workflows/v2/tournament_stream.json

POST v2/tournaments/stream {code, url}: the organiser sets, changes or (url empty) removes the tournament's YouTube live
link. Any YouTube link form is accepted (youtube.com/live/ID, youtu.be/ID, watch?v=ID, shorts, embed) and stored as
https://www.youtube.com/watch?v=ID; the app shows a Live tab with the video only when a link is set.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_web_registration.py')).read().split('\nout = {}\n')[0])  # node helpers
APP_AUTH = open(os.path.join(HERE, '_app_auth.js')).read()
OUT = os.path.join(HERE, '..', 'workflows', 'v2')

CHECK_JS = APP_AUTH + r"""
const auth = verifyToken($json.headers);
if (!auth.ok) return [{ json: { ok: false, status: 401, body: { success: false, message: auth.error } } }];
const b = $json.body || {};
const code = String(b.code || '').trim().toUpperCase();
if (!/^[A-Z0-9]{6}$/.test(code)) return [{ json: { ok: false, status: 422, body: { success: false, message: 'Tournament not found.' } } }];
const raw = String(b.url || '').trim();
let url = null;
if (raw) {
  const m = raw.match(/^(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?(?:.*&)?v=|live\/|shorts\/|embed\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/);
  if (!m) return [{ json: { ok: false, status: 422, body: { success: false, message: 'Paste a YouTube link, e.g. youtube.com/live/… or youtu.be/…' } } }];
  url = `https://www.youtube.com/watch?v=${m[1]}`;
}
return [{ json: { ok: true, phone: auth.phone, code, url } }];
"""

n, c = [], {}
n.append(webhook("v2/tournaments/stream", "POST"))
n.append(code("Check Request", CHECK_JS, [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Save Link",
    "UPDATE tournaments t JOIN app_users u ON u.phone = $1 AND u.id = t.organizer_user_id SET t.stream_url = $3 WHERE t.code = $2; "
    "SELECT COUNT(*) AS n FROM tournaments t JOIN app_users u ON u.phone = $1 AND u.id = t.organizer_user_id WHERE t.code = $2",
    "={{ [$json.phone, $json.code, $json.url] }}", [660, -100], always=True))
n.append(code("Build Response", r"""
const r = $('Check Request').first().json;
const owner = $input.all().some(i => Number(i.json.n) === 1);
if (!owner) return [{ json: { status: 403, body: { success: false, message: 'Only the organiser can change the live link.' } } }];
return [{ json: { status: 200, body: { success: true, stream_url: r.url, message: r.url ? 'Live link saved.' : 'Live link removed.' } } }];
""", [880, -100]))
n.append(respond([1100, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Save Link", 0); link(c, "Valid?", "Respond", 1)
link(c, "Save Link", "Build Response"); link(c, "Build Response", "Respond")
w = workflow("TourStream026mP", "MyPaltan v2 - Tournament Stream", n, c)
json.dump(w, open(os.path.join(OUT, 'tournament_stream.json'), 'w'), indent=2)
print('tournament_stream', w['id'], len(w['nodes']), 'nodes')
