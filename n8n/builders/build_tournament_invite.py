"""Builds the tournament entry-type / invite-code workflow (app: tournament page → About → Open / In-house card).

  python3 build_tournament_invite.py   → writes ../workflows/v2/tournament_invite.json

POST v2/tournaments/invite {code, entry_type?, reset?}: the organiser switches the tournament between OPEN (anyone can
register a team) and IN_HOUSE (only teams with the invite code), or gets a new invite code (the old one stops working).
Every tournament is listed for everyone either way; in-house only limits who can register.
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
const type = b.entry_type == null ? null : String(b.entry_type).toUpperCase();
if (type !== null && !['OPEN', 'IN_HOUSE'].includes(type)) return [{ json: { ok: false, status: 422, body: { success: false, message: 'Choose Open or In-house.' } } }];
const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const fresh = Array.from(require('crypto').randomBytes(6), x => letters[x % letters.length]).join('');
return [{ json: { ok: true, phone: auth.phone, code, type, reset: b.reset === true, fresh } }];
"""

# In-house keeps its code unless reset (or it has none); Open has no code.
SAVE_SQL = (
    "UPDATE tournaments t JOIN app_users u ON u.phone = $1 AND u.id = t.organizer_user_id "
    "SET t.entry_type = COALESCE($3, t.entry_type), "
    "t.invite_code = IF(COALESCE($3, t.entry_type) = 'IN_HOUSE', IF($4 = 1 OR t.invite_code IS NULL, $5, t.invite_code), NULL) "
    "WHERE t.code = $2 AND t.status <> 'DRAFT'; "
    "SELECT t.entry_type, t.invite_code FROM tournaments t JOIN app_users u ON u.phone = $1 AND u.id = t.organizer_user_id WHERE t.code = $2"
)

n, c = [], {}
n.append(webhook("v2/tournaments/invite", "POST"))
n.append(code("Check Request", CHECK_JS, [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Save", SAVE_SQL, "={{ [$json.phone, $json.code, $json.type, $json.reset ? 1 : 0, $json.fresh] }}", [660, -100], always=True))
n.append(code("Build Response", r"""
const row = $input.all().map(i => i.json).find(r => r && r.entry_type);
if (!row) return [{ json: { status: 403, body: { success: false, message: 'Only the organiser can change this.' } } }];
const r = $('Check Request').first().json;
const message = row.entry_type === 'OPEN' ? 'Open: any team can register.' : r.reset ? 'New invite code made. The old one no longer works.' : 'In-house: teams register with your invite code.';
return [{ json: { status: 200, body: { success: true, entry_type: row.entry_type, invite_code: row.invite_code || null, message } } }];
""", [880, -100]))
n.append(respond([1100, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Save", 0); link(c, "Valid?", "Respond", 1)
link(c, "Save", "Build Response"); link(c, "Build Response", "Respond")
w = workflow("TourInvite026mP", "MyPaltan v2 - Tournament Invite", n, c)
json.dump(w, open(os.path.join(OUT, 'tournament_invite.json'), 'w'), indent=2)
print('tournament_invite', w['id'], len(w['nodes']), 'nodes')
