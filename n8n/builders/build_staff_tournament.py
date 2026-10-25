"""Builds the admin-portal workflows for tournament web registrations (mypaltan.com/approvals → tournament tab).

  python3 build_staff_tournament.py   → writes ../workflows/v2/staff_tournament_teams.json and staff_tournament_team_update.json

Staff (superadmin) see every team registered for a tournament with a web link, with payments and squads, and can
confirm or reject teams. Confirm / reject follow the app's organiser rules exactly (see entry_update.json), so the
organiser's app shows the same result.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, 'build_web_registration.py')).read().split('\nout = {}\n')[0]
exec(_src)  # node helpers and constants
STAFF_AUTH = open(os.path.join(HERE, '_staff_auth.js')).read()


def staff_gate(n, c, after, x):
    """Re-reads the staff account on every request; only an active superadmin may continue."""
    n.append(mysql("Load Staff", "SELECT id, name, role, is_active FROM users WHERE id = $1", "={{ [$json.sid] }}", [x, -100], always=True))
    n.append(code("Is Superadmin", r"""
const s = $json;
if (!s.id || Number(s.is_active) !== 1) return [{ json: { ok: false, status: 401, body: { success: false, message: 'Please log in again.' } } }];
if (s.role !== 'superadmin') return [{ json: { ok: false, status: 403, body: { success: false, message: 'Only the MyPaltan owner can review approvals.' } } }];
return [{ json: { ok: true, sid: s.id } }];""", [x + 220, -100]))
    n.append(iff("Allowed?", "={{ $json.ok }}", [x + 440, -100]))
    link(c, after, "Load Staff"); link(c, "Load Staff", "Is Superadmin"); link(c, "Is Superadmin", "Allowed?")


out = {}

# ───────────── 1. Teams of a tournament (with payments, screenshots and squads) ─────────────
n, c = [], {}
n.append(webhook("v2/staff/tournament-teams", "GET"))
n.append(code("Check Token", STAFF_AUTH + r"""
const slug = String($json.query?.slug ?? '').toLowerCase();
if (!/^[a-z0-9-]{2,40}$/.test(slug)) return [{ json: { ok: false, status: 422, body: { success: false, message: 'Unknown tournament link.' } } }];
return [{ json: { ok: true, sid: auth.sid, slug } }];""", [220, 0]))
n.append(iff("Token OK?", "={{ $json.ok }}", [440, 0]))
staff_gate(n, c, "Token OK?", 660)
c["Token OK?"]["main"] = [[{"node": "Load Staff", "type": "main", "index": 0}], [{"node": "Respond", "type": "main", "index": 0}]]
n.append(mysql("Load Teams",
    "SELECT l.slug, l.fee_per_player, t.id AS tid, t.code, t.name, DATE_FORMAT(t.start_date, '%Y-%m-%d') AS start_date, "
    "DATE_FORMAT(t.registration_deadline, '%Y-%m-%d %H:%i') AS deadline, o.name AS organiser, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('id', d.id, 'name', d.name, 'max_teams', d.max_teams, 'squad_max', d.squad_max, 'max_age', d.max_age, "
    "'approved', (SELECT COUNT(*) FROM tournament_entries x WHERE x.division_id = d.id AND x.status = 'APPROVED'))) "
    "FROM tournament_divisions d WHERE d.tournament_id = t.id) AS divisions, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('id', e.id, 'status', e.status, 'division_id', e.division_id, 'team', tm.name, 'team_code', tm.code, "
    "'logo_key', tm.logo_key, 'area', tm.area, 'coach', u.name, 'coach_phone', u.phone, 'amount', e.amount, 'paid_players', e.paid_players, "
    "'utr', e.utr, 'proof_key', e.proof_key, 'reject_reason', e.reject_reason, 'web', e.manage_key_hash IS NOT NULL, "
    "'registered', DATE_FORMAT(CONVERT_TZ(e.created_at, '+00:00', '+05:30'), '%Y-%m-%d %H:%i'), "
    "'reviewed', DATE_FORMAT(CONVERT_TZ(e.reviewed_at, '+00:00', '+05:30'), '%Y-%m-%d %H:%i'), "
    "'waiting', (SELECT COUNT(*) FROM team_members w WHERE w.team_id = tm.id AND w.status = 'PENDING'), "
    "'payments', (SELECT JSON_ARRAYAGG(JSON_OBJECT('players', p.players, 'amount', p.amount, 'utr', p.utr, 'proof_key', p.proof_key, "
    "'at', DATE_FORMAT(CONVERT_TZ(p.created_at, '+00:00', '+05:30'), '%Y-%m-%d %H:%i'))) FROM entry_payments p WHERE p.entry_id = e.id), "
    "'squad', (SELECT JSON_ARRAYAGG(JSON_OBJECT('name', COALESCE(au.name, m.guest_name), "
    "'birthdate', DATE_FORMAT(COALESCE(au.birthdate, m.guest_birthdate), '%Y-%m-%d'), "
    "'age', TIMESTAMPDIFF(YEAR, COALESCE(au.birthdate, m.guest_birthdate), t.start_date), 'gender', COALESCE(au.gender, m.guest_gender), "
    "'jersey', COALESCE(ep.jersey_number, m.jersey_number, au.jersey_number), 'parent_phone', m.parent_phone, "
    "'photo_key', COALESCE(m.guest_photo_key, au.photo_key))) "
    "FROM tournament_entry_players ep JOIN team_members m ON m.id = ep.team_member_id LEFT JOIN app_users au ON au.id = m.user_id WHERE ep.entry_id = e.id))) "
    "FROM tournament_entries e JOIN teams tm ON tm.id = e.team_id JOIN app_users u ON u.id = e.registered_by WHERE e.tournament_id = t.id) AS entries "
    "FROM tournament_web_links l JOIN tournaments t ON t.id = l.tournament_id JOIN app_users o ON o.id = t.organizer_user_id WHERE l.slug = $1",
    "={{ [$('Check Token').first().json.slug] }}", [1320, -200], always=True))
link(c, "Allowed?", "Load Teams", 0); link(c, "Allowed?", "Respond", 1)
n.append(code("B2 Credentials", B2_AUTH, [1540, -200]))
au = http("Authorize B2", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [1740, -200])
au["onError"] = "continueRegularOutput"
n.append(au)
for i, (name, prefix) in enumerate([("Team Link", "team_assets/"), ("Proof Link", "payment_proof/")]):
    h = http(name, "POST", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_download_authorization",
             [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}"), ("Content-Type", "application/json")], [1940 + 200 * i, -200],
             json_body="={{ JSON.stringify({ bucketId: '" + BUCKET_ID + "', fileNamePrefix: '" + prefix + "', validDurationInSeconds: 86400 }) }}")
    h["onError"] = "continueRegularOutput"
    n.append(h)
n.append(code("Build Response", r"""
const r = $('Load Teams').first().json;
if (!r.tid) return [{ json: { status: 404, body: { success: false, message: 'No tournament has this registration link.' } } }];
const b2 = $('Authorize B2').first().json || {};
const dl = b2.apiInfo ? b2.apiInfo.storageApi.downloadUrl : null;
const tok = n => { try { return $(n).first().json.authorizationToken || null; } catch { return null; } };
const tokens = { 'team_assets/': tok('Team Link'), 'payment_proof/': tok('Proof Link') };
const sign = k => { if (!k || !dl) return null; const p = Object.keys(tokens).find(x => k.startsWith(x)); const t = p && tokens[p];
  return t ? `${dl}/file/""" + BUCKET_NAME + r"""/${k.split('/').map(encodeURIComponent).join('/')}?Authorization=${t}` : null; };
const parse = v => { if (v == null) return null; if (typeof v === 'object') return v; try { return JSON.parse(v); } catch { return null; } };
const divisions = (parse(r.divisions) || []).sort((a, b) => a.id - b.id);
const teams = (parse(r.entries) || []).map(e => ({
  id: e.id, status: e.status, division_id: e.division_id, team: e.team, team_code: e.team_code, logo_url: sign(e.logo_key), area: e.area,
  coach: e.coach, coach_phone: e.coach_phone, amount: e.amount, paid_players: e.paid_players, utr: e.utr, reject_reason: e.reject_reason,
  web: !!e.web, registered: e.registered, reviewed: e.reviewed, waiting: Number(e.waiting || 0),
  payments: (parse(e.payments) || []).map(({ proof_key, ...p }) => ({ ...p, proof_url: sign(proof_key) })),
  proof_url: sign(e.proof_key),
  squad: (parse(e.squad) || []).map(({ photo_key, ...m }) => ({ ...m, photo_url: sign(photo_key) })).sort((a, b) => String(a.name).localeCompare(String(b.name))),
})).sort((a, b) => String(a.registered).localeCompare(String(b.registered)));
return [{ json: { status: 200, body: { success: true, tournament: { code: r.code, name: r.name, start_date: r.start_date, deadline: r.deadline,
  organiser: r.organiser, slug: r.slug, fee_per_player: Number(r.fee_per_player) }, divisions, teams } } }];""", [2400, -200]))
n.append(respond([2620, 0]))
link(c, "Load Teams", "B2 Credentials"); link(c, "B2 Credentials", "Authorize B2"); link(c, "Authorize B2", "Team Link"); link(c, "Team Link", "Proof Link")
link(c, "Proof Link", "Build Response"); link(c, "Build Response", "Respond")
link(c, "Webhook", "Check Token"); link(c, "Check Token", "Token OK?")
out['staff_tournament_teams'] = workflow("StfTrnTms026mPxJ", "MyPaltan v2 - Staff Tournament Teams", n, c)

# ───────────── 2. Confirm or reject a team (same rules and messages as the organiser in the app) ─────────────
n, c = [], {}
n.append(webhook("v2/staff/tournament-teams/update", "POST"))
n.append(code("Check Request", STAFF_AUTH + SHA256 + r"""
const b = $json.body || {};
const bad = m => [{ json: { ok: false, status: 422, body: { success: false, message: m } } }];
const id = Number(b.entry_id), action = String(b.action ?? '').toUpperCase();
if (!(Number.isInteger(id) && id > 0) || !['APPROVE', 'REJECT', 'NEW_LINK'].includes(action)) return bad('Invalid request.');
const reason = String(b.reason ?? '').trim().replace(/\s+/g, ' ');
if (action === 'REJECT' && (reason.length < 3 || reason.length > 200)) return bad('Write a short reason for the coach (3-200 characters).');
// NEW_LINK: a fresh private coach link (the old one stops working). Only its SHA-256 is stored.
const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
const g = globalThis.crypto && globalThis.crypto.getRandomValues ? globalThis.crypto.getRandomValues(new Uint32Array(32)) : null;
const key = Array.from({ length: 32 }, (_, i) => chars[(g ? g[i] : Math.floor(Math.random() * 4294967296)) % chars.length]).join('');
return [{ json: { ok: true, sid: auth.sid, id, action, reason, key, key_hash: sha256hex(key) } }];""", [220, 0]))
n.append(iff("Request OK?", "={{ $json.ok }}", [440, 0]))
staff_gate(n, c, "Request OK?", 660)
c["Request OK?"]["main"] = [[{"node": "Load Staff", "type": "main", "index": 0}], [{"node": "Respond", "type": "main", "index": 0}]]
n.append(mysql("Load Entry",
    "SELECT e.id, e.status, e.registered_by, e.division_id, t.code, t.name AS tname, t.organizer_user_id, tm.name AS team_name, d.name AS dname, d.max_teams, "
    "(SELECT l.slug FROM tournament_web_links l WHERE l.tournament_id = t.id LIMIT 1) AS slug, (SELECT u.phone FROM app_users u WHERE u.id = e.registered_by) AS coach_phone, "
    "(SELECT COUNT(*) FROM tournament_entries x WHERE x.division_id = e.division_id AND x.status = 'APPROVED') AS approved "
    "FROM tournament_entries e JOIN tournaments t ON t.id = e.tournament_id JOIN teams tm ON tm.id = e.team_id "
    "LEFT JOIN tournament_divisions d ON d.id = e.division_id WHERE e.id = $1",
    "={{ [$('Check Request').first().json.id] }}", [1320, -200], always=True))
link(c, "Allowed?", "Load Entry", 0); link(c, "Allowed?", "Respond", 1)
n.append(code("Plan", r"""
const s = $json, r = $('Check Request').first().json;
const fail = (st, m) => [{ json: { ok: false, status: st, body: { success: false, message: m } } }];
if (!s.id) return fail(404, 'Registration not found.');
// Staff act on behalf of the organiser, so the review is recorded under the organiser's account.
const reviewer = s.organizer_user_id;
let sql, params, message, note;
if (r.action === 'NEW_LINK') {
  if (!s.slug) return fail(409, 'This tournament has no web registration link.');
  return [{ json: { ok: true, sql: 'UPDATE tournament_entries SET manage_key_hash = $1 WHERE id = $2', params: [r.key_hash, s.id],
    message: `New coach link for ${s.team_name}. The old link no longer works.`, link: { path: `/register/${s.slug}/manage/${r.key}`, coach_phone: s.coach_phone, team: s.team_name } } }];
}
if (r.action === 'APPROVE') {
  if (!['PENDING', 'WAITLISTED'].includes(s.status)) return fail(409, 'This registration is not waiting for approval.');
  if (Number(s.approved) >= Number(s.max_teams)) return fail(409, `${s.dname} is full (${s.max_teams} teams). Reject a team or add places first.`);
  sql = "UPDATE tournament_entries SET status = 'APPROVED', reviewed_by = $1, reviewed_at = NOW(), reject_reason = NULL WHERE id = $2";
  params = [reviewer, s.id];
  note = [`${s.team_name} is confirmed`, `You're in ${s.dname} of ${s.tname}. See you on the field!`];
  message = `${s.team_name} confirmed.`;
} else {
  if (!['PENDING', 'WAITLISTED', 'APPROVED'].includes(s.status)) return fail(409, 'This registration is not active.');
  sql = "UPDATE tournament_entries SET status = 'REJECTED', reject_reason = $1, reviewed_by = $2, reviewed_at = NOW() WHERE id = $3; DELETE FROM tournament_entry_players WHERE entry_id = $4";
  params = [r.reason, reviewer, s.id, s.id];
  note = [`${s.team_name} was not accepted`, `${s.dname} of ${s.tname}: ${r.reason}. You can fix this and register again.`];
  message = `${s.team_name} rejected.`;
}
const k = params.length;
sql += `; INSERT INTO notifications (user_id, type, title, body, data) VALUES ($${k + 1}, 'ENTRY', $${k + 2}, $${k + 3}, JSON_OBJECT('tournament_code', $${k + 4}))`;
params.push(s.registered_by, note[0], note[1], s.code);
return [{ json: { ok: true, sql, params, message } }];""", [1540, -200]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1760, -200]))
n.append(mysql("Run", "={{ $json.sql }}", "={{ $json.params }}", [1980, -300], continue_on_error=True))
n.append(code("Build Response", r"""
if ($json.error || /ER_|syntax/i.test(String($json.message || ''))) return [{ json: { status: 500, body: { success: false, message: 'Could not save. Please try again.' } } }];
const p = $('Plan').first().json;
return [{ json: { status: 200, body: { success: true, message: p.message, ...(p.link ? { link: p.link } : {}) } } }];""", [2200, -300]))
n.append(respond([2420, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Request OK?")
link(c, "Load Entry", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Run", 0); link(c, "Plan OK?", "Respond", 1)
link(c, "Run", "Build Response"); link(c, "Build Response", "Respond")
out['staff_tournament_team_update'] = workflow("StfTrnUpd026mPxK", "MyPaltan v2 - Staff Tournament Team Update", n, c)

for k, w in out.items():
    json.dump(w, open(os.path.join(OUT, f'{k}.json'), 'w'), indent=2)
    print(k, w['id'], len(w['nodes']), 'nodes')
json.dump({f"{k}::{nd['name']}": nd['parameters']['jsCode'] for k, w in out.items() for nd in w['nodes'] if nd['type'].endswith('.code')},
          open(os.path.join(HERE, '_codes_staff_tournament.json'), 'w'))
