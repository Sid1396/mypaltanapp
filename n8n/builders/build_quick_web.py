"""Builds the website side of Quick match: people without the app see the match and join with name + mobile number.

  python3 build_quick_web.py
    → writes ../workflows/v2/quick_public.json, quick_web_join.json and patches public_tournament.json (adds kind)

  GET  v2/public/quick?code=MATCH[&team=TEAMCODE]   the match page / team link page (no login)
  POST v2/public/quick/join {code, name, phone, team_code?}
       "I'm in" (no team_code) or join one team's squad (team link). New numbers get a basic MyPaltan account
       (name + phone); when that person installs the app and logs in with the number, it is theirs.

No OTP yet (SMS is not live): anyone can type any number, so the page never shows phone numbers or full names
(players appear as "First L.") and the reply never says whose number it is. The join returns a pass (30 days) so the
page remembers "you" on that phone. Captains, the PIN and scoring stay in the app.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_web_registration.py')).read().split('\nout = {}\n')[0])  # node helpers, rate(), COMMON
_ca = open(os.path.join(HERE, '_coach_auth.js')).read()
SHA = _ca[:_ca.index('\n}\n', _ca.index('function hmacSha256')) + 3]  # sha256bytes + hmacSha256

PASS = SHA + r"""
function b64url(buf) { return Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, ''); }
const PASS_KEY = () => `${$env.JWT_SECRET}|mypaltan-quickweb`;
function signPass(phone) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const body = b64url(Buffer.from(JSON.stringify({ typ: 'quickweb', phone, iat: now, exp: now + 30 * 24 * 60 * 60 })));
  return `${header}.${body}.${b64url(hmacSha256(PASS_KEY(), `${header}.${body}`))}`;
}
// The phone in a valid pass, or '' (no pass, expired or forged).
function passPhone(headers) {
  const auth = String((headers || {}).authorization || '').trim();
  const parts = (auth.startsWith('Bearer ') ? auth.slice(7).trim() : '').split('.');
  if (parts.length !== 3) return '';
  const [h, p, s] = parts;
  if (b64url(hmacSha256(PASS_KEY(), `${h}.${p}`)) !== s) return '';
  try {
    const c = JSON.parse(Buffer.from(p, 'base64').toString('utf8'));
    return c.typ === 'quickweb' && c.exp > Math.floor(Date.now() / 1000) && /^[6-9]\d{9}$/.test(String(c.phone)) ? String(c.phone) : '';
  } catch { return ''; }
}
"""

# Match, both sides with squads, the "I'm in" list, and who the viewer is (by phone; '' = nobody).
LOAD = (
    "SELECT t.id AS tid, t.code, t.sport, t.name, t.status, t.area, d.squad_max, d.match_rules, "
    "m.id AS match_id, m.status AS match_status, m.event_count, DATE_FORMAT(m.scheduled_at, '%Y-%m-%d %H:%i') AS scheduled_at, "
    "m.result_text, m.home_entry_id, m.away_entry_id, JSON_EXTRACT(m.live, '$.summary') AS summary, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('entry_id', e.id, 'team_id', tm.id, 'team_code', tm.code, 'name', tm.name, 'registered_by', e.registered_by, "
    "'captain_id', (SELECT x.user_id FROM team_members x WHERE x.team_id = tm.id AND x.role = 'CAPTAIN' AND x.status = 'ACTIVE' LIMIT 1), "
    "'players', (SELECT JSON_ARRAYAGG(JSON_OBJECT('user_id', ep.user_id, 'name', COALESCE(u.name, x.guest_name))) "
    "FROM tournament_entry_players ep JOIN team_members x ON x.id = ep.team_member_id LEFT JOIN app_users u ON u.id = x.user_id WHERE ep.entry_id = e.id))) "
    "FROM tournament_entries e JOIN teams tm ON tm.id = e.team_id WHERE e.tournament_id = t.id) AS sides, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('user_id', p.user_id, 'name', pu.name)) FROM quick_match_people p JOIN app_users pu ON pu.id = p.user_id "
    "WHERE p.tournament_id = t.id) AS people, t.organizer_user_id, "
    "(SELECT CONCAT_WS('|', v.id, v.is_active) FROM app_users v WHERE v.phone = $2 AND $2 <> '') AS viewer "
    "FROM tournaments t JOIN tournament_divisions d ON d.tournament_id = t.id JOIN tournament_matches m ON m.tournament_id = t.id "
    "WHERE t.code = $1 AND t.kind = 'QUICK'"
)

SHAPE = r"""
const parse = v => { if (v == null) return null; if (typeof v === 'object') return v; try { return JSON.parse(v); } catch { return null; } };
// Public pages: "Aarav S." (no full names; anyone with the link can see this page).
const short = n => { const w = String(n || '').trim().split(/\s+/).filter(Boolean); return w.length ? (w.length > 1 ? `${w[0]} ${w[w.length - 1][0].toUpperCase()}.` : w[0]) : 'Player'; };
const [vid, vactive] = String(s.viewer || '').split('|');
const me = vid ? Number(vid) : null;
const sides = (parse(s.sides) || []).map(x => ({ ...x, side: Number(x.entry_id) === Number(s.home_entry_id) ? 'HOME' : 'AWAY',
  captain_id: x.captain_id == null ? null : Number(x.captain_id), players: parse(x.players) || [] }))
  .sort((a, b) => (a.side === 'HOME' ? 0 : 1) - (b.side === 'HOME' ? 0 : 1));
const people = parse(s.people) || [];
const open = s.match_status === 'SCHEDULED' && Number(s.event_count) === 0 && s.status !== 'CANCELLED';
const mySide = me == null ? null : sides.find(x => x.players.some(p => Number(p.user_id) === me)) || null;
"""

out = {}

# ───────────── 1. Public match / team page ─────────────
n, c = [], {}
w = webhook("v2/public/quick", "GET")
n.append(w)
n.append(code("Check Request", rate(600) + PASS + r"""
const q = $in.query || {};
const code = String(q.code ?? '').toUpperCase(), team = String(q.team ?? '').toUpperCase();
const bad = (m, st = 404) => [{ json: { ok: false, status: st, body: { success: false, message: m } } }];
if (!/^[A-Z0-9]{6}$/.test(code)) return bad('This match link is not valid.');
if (team && !/^[A-Z0-9]{6}$/.test(team)) return bad('This team link is not valid.');
count();
return [{ json: { ok: true, code, team, phone: passPhone($in.headers) } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load", LOAD, "={{ [$json.code, $json.phone] }}", [660, -100], always=True))
n.append(code("Build Response", r"""
const s = $json, r = $('Check Request').first().json;
if (!s.tid) return [{ json: { status: 404, body: { success: false, message: 'This match link is not valid.' } } }];
""" + SHAPE + r"""
const team = r.team ? sides.find(x => x.team_code === r.team) : null;
if (r.team && !team) return [{ json: { status: 404, body: { success: false, message: 'This team is not in this match.' } } }];
const summary = parse(s.summary) || {};
const names = Object.fromEntries(sides.map(x => [String(x.entry_id), x.name]));
const rules = parse(s.match_rules) || {};
const match = {
  code: s.code, sport: s.sport, name: s.name, status: s.status, ground: s.area === 'Quick match' ? '' : s.area,
  scheduled_at: s.scheduled_at, match_status: s.match_status, started: Number(s.event_count) > 0, open,
  rules: { overs: rules.overs ?? null, half_minutes: rules.half_minutes ?? null, last_batter: rules.last_batter === true,
    event: rules.event ?? null, games: rules.games ?? null, points_per_game: rules.points_per_game ?? null },
  result_text: s.result_text ? String(s.result_text).replace(/\{(\d+)\}/g, (_, id) => names[id] || 'Team') : null,
  sides: sides.map(x => ({ side: x.side, name: x.name, score: summary[String(x.entry_id)] ?? null, squad_max: Number(s.squad_max),
    captain: x.captain_id == null ? null : short((x.players.find(p => Number(p.user_id) === x.captain_id) || {}).name),
    players: x.players.map(p => short(p.name)).sort() })),
  in_list: people.length,
  people: people.map(p => short(p.name)).sort(),
  me: me == null ? null : { in_list: people.some(p => Number(p.user_id) === me), side: mySide ? mySide.side : null },
  ...(team ? { team: { side: team.side, name: team.name, players: team.players.length, squad_max: Number(s.squad_max) } } : {}),
};
return [{ json: { status: 200, body: { success: true, match } } }];""", [880, -100]))
n.append(respond([1100, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Build Response"); link(c, "Build Response", "Respond")
out['quick_public'] = workflow("QuickPublic026mP", "MyPaltan v2 - Quick Match Public", n, c)

# ───────────── 2. Join from the website: name + mobile number ─────────────
n, c = [], {}
n.append(webhook("v2/public/quick/join", "POST"))
n.append(code("Check Request", rate(30) + COMMON + r"""
const code = str(b.code).toUpperCase(), team = str(b.team_code).toUpperCase();
const phone = str(b.phone).replace(/\D/g, '').slice(-10), name = str(b.name).replace(/\s+/g, ' ');
if (!/^[A-Z0-9]{6}$/.test(code)) return bad('This match link is not valid.', 404);
if (team && !/^[A-Z0-9]{6}$/.test(team)) return bad('This team link is not valid.', 404);
if (name.length < 2 || name.length > 50 || !/^[\p{L}][\p{L} .'-]*$/u.test(name)) return bad('Enter your name.');
if (!/^[6-9]\d{9}$/.test(phone)) return bad('Enter your 10-digit mobile number.');
count();
return [{ json: { ok: true, code, team, phone, name } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load", LOAD, "={{ [$json.code, $json.phone] }}", [660, -100], always=True))
n.append(code("Plan", r"""
const s = $json, r = $('Check Request').first().json;
const fail = (st, m) => [{ json: { ok: false, status: st, body: { success: false, message: m } } }];
if (!s.tid) return fail(404, 'This match link is not valid.');
""" + SHAPE + r"""
if (s.status === 'CANCELLED') return fail(409, 'This match was cancelled.');
if (!open) return fail(409, 'This match has already started, so new players cannot join.');
if (me != null && vactive !== '1') return fail(403, 'This mobile number cannot join matches.');
const team = r.team ? sides.find(x => x.team_code === r.team) : null;
if (r.team && !team) return fail(404, 'This team is not in this match.');
if (team) {
  if (mySide && mySide.side !== team.side) return fail(409, `This number is already playing for ${mySide.name}.`);
  if (!mySide && team.players.length >= Number(s.squad_max)) return fail(409, `${team.name} is full (${s.squad_max} players). Ask the captain.`);
}
const p = [], stmts = ['START TRANSACTION'];
const add = v => { p.push(v); return '$' + p.length; };
const notify = (user, title, body) => stmts.push(`INSERT INTO notifications (user_id, type, title, body, data) VALUES (${add(user)}, 'ENTRY', ${add(title)}, ${add(body)}, JSON_OBJECT('tournament_code', ${add(s.code)}))`);
// A new number gets a basic account; an existing account keeps its own name.
stmts.push(`INSERT INTO app_users (phone, name) SELECT ${add(r.phone)}, ${add(r.name)} FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM app_users WHERE phone = ${add(r.phone)})`);
stmts.push(`SET @u = (SELECT id FROM app_users WHERE phone = ${add(r.phone)})`);
stmts.push(`INSERT IGNORE INTO quick_match_people (tournament_id, user_id) VALUES (${add(s.tid)}, @u)`);
const inList = me != null && people.some(x => Number(x.user_id) === me);
let message;
if (team && !(mySide && mySide.side === team.side)) {
  stmts.push(`INSERT INTO team_members (team_id, user_id, role, added_by) VALUES (${add(team.team_id)}, @u, 'PLAYER', @u) ON DUPLICATE KEY UPDATE status = 'ACTIVE'`);
  stmts.push(`SET @m = (SELECT id FROM team_members WHERE team_id = ${add(team.team_id)} AND user_id = @u)`);
  stmts.push(`INSERT INTO tournament_entry_players (entry_id, tournament_id, team_member_id, user_id) VALUES (${add(team.entry_id)}, ${add(s.tid)}, @m, @u)`);
  const who = me == null ? r.name : 'A player';
  if (team.registered_by) notify(Number(team.registered_by), `${who} joined ${team.name}`, `${s.name}: ${team.players.length + 1} of ${s.squad_max} players.`);
  message = `You're in ${team.name}!`;
} else if (team) {
  message = `You're already in ${team.name}.`;
} else {
  if (!inList) notify(Number(s.organizer_user_id), `${me == null ? r.name : 'Someone'} is in`, `${s.name}: pick captains and make the teams when everyone is in.`);
  message = inList ? "You're already in." : "You're in! The organiser will put you in a team.";
}
stmts.push('COMMIT');
return [{ json: { ok: true, sql: stmts.join('; '), params: p, message, side: team ? team.side : (mySide ? mySide.side : null) } }];""", [880, -100]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1100, -100]))
n.append(mysql("Save", "={{ $json.sql }}", "={{ $json.params }}", [1320, -200], continue_on_error=True))
n.append(code("Build Response", PASS + r"""
const msg = String($in.message || $in.error?.message || '');
if (msg.includes('uq_tournament_user')) return [{ json: { status: 409, body: { success: false, message: 'This number is already playing for the other team.' } } }];
if ($in.error || /ER_|Duplicate|constraint|syntax/i.test(msg)) return [{ json: { status: 500, body: { success: false, message: 'Could not join. Please try again.' } } }];
const plan = $('Plan').first().json, r = $('Check Request').first().json;
return [{ json: { status: 200, body: { success: true, message: plan.message, side: plan.side, token: signPass(r.phone) } } }];""", [1540, -200]))
n.append(respond([1760, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Save", 0); link(c, "Plan OK?", "Respond", 1)
link(c, "Save", "Build Response"); link(c, "Build Response", "Respond")
out['quick_web_join'] = workflow("QuickWebJoin026m", "MyPaltan v2 - Quick Match Web Join", n, c)


# ───────────── Patch: the public tournament page says when a code is a quick match ─────────────
def rep(s, a, b):
    if b in s:
        return s  # already patched
    assert s.count(a) == 1, (a[:90], s.count(a))
    return s.replace(a, b)


pt = json.load(open(os.path.join(OUT, 'public_tournament.json')))
out['public_tournament'] = pt
for x in pt['nodes']:
    if x['name'] == 'Load Tournament':
        x['parameters']['query'] = rep(x['parameters']['query'], "SELECT t.id, t.code, ", "SELECT t.id, t.code, t.kind, ")
    if x['name'] == 'Found?':
        cond = x['parameters']['conditions']['conditions'][0]
        cond['leftValue'] = rep(cond['leftValue'], "={{ !!$json.id }}", "={{ !!$json.id && $json.kind !== 'QUICK' }}")
    if x['name'] == 'Not Found':
        # Quick matches have their own page on the website; tell it which page to show.
        x['parameters']['jsCode'] = rep(x['parameters']['jsCode'],
            "return [{ json: { status: 404, body: { success: false, message: 'Tournament not found.' } } }];",
            "const t = $('Load Tournament').first().json;\n"
            "if (t.id && t.kind === 'QUICK') return [{ json: { status: 200, body: { success: true, kind: 'QUICK', code: t.code } } }];\n"
            "return [{ json: { status: 404, body: { success: false, message: 'Tournament not found.' } } }];")

for k, w in out.items():
    json.dump(w, open(os.path.join(OUT, f'{k}.json'), 'w'), indent=2)
    print(k, w['id'], len(w['id']), len(w['nodes']), 'nodes')
