"""Builds the Quick match workflows (app only) and the small changes other workflows need for them.

  python3 build_quick_match.py
    → writes ../workflows/v2/quick_create.json, quick_detail.json, quick_action.json, quick_mine.json
      and patches tournament_mine, tournament_detail, tournament_publish, entry_register, entry_options,
      fixtures_generate, fixtures_action (from their copies in ../workflows/v2, which match live)

A quick match is a friendly game between two teams, made by one person and shared as a link in a group.
It is stored as a private tournament with kind = 'QUICK': one division ("Match"), two teams, two approved entries
and one match, so squads, toss / line-ups, scoring, scorecards and player of the match all work as in tournaments.

  - The creator makes it (sport, team names, rules, ground, time) and may play for one side as its captain.
  - People who open the link tap "I'm in" (quick_match_people). The creator picks each side's captain from them.
  - A captain shares the team link (mypaltan.com/team/CODE?t=MATCHCODE); players join that team's squad through
    the normal squad join (it locks itself once scoring starts, because the tournament becomes LIVE).
  - Captains see the scoring PIN and become scorers; others score by entering the PIN, as in tournaments.
Quick matches never appear in My tournaments, Discover or the staff queue, and can't take registrations,
fixtures or be made public.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_web_registration.py')).read().split('\nout = {}\n')[0])  # node helpers, DEFAULT_TEAM_LOGO
APP_AUTH = open(os.path.join(HERE, '_app_auth.js')).read()

SPORTS = "['CRICKET', 'FOOTBALL', 'BADMINTON', 'PICKLEBALL']"

AUTH = APP_AUTH + r"""
const auth = verifyToken($in.headers);
if (!auth.ok) return [{ json: { ok: false, status: 401, body: { success: false, message: auth.error } } }];
const b = $in.body || {};
const bad = (m, status = 422) => [{ json: { ok: false, status, body: { success: false, message: m } } }];
const str = v => String(v ?? '').trim().replace(/\s+/g, ' ');
"""

# Rules for a quick match (create and "Next match"). Returns { rules, squadMax } or { error }.
RULES = r"""
function rulesFor(sport, r) {
  r = r && typeof r === 'object' ? r : {};
  const int = (k, d, lo, hi) => { const v = Number(r[k] ?? d); return Number.isInteger(v) && v >= lo && v <= hi ? v : null; };
  // Team sizes follow whoever the creator puts in each team (cricket up to 11, football up to 15 with rolling subs);
  // cricket's "all out" counts each team's own players.
  if (sport === 'CRICKET') {
    const overs = int('overs', 6, 1, 50);
    if (overs == null) return { error: 'Overs must be between 1 and 50.' };
    // Short friendlies: 2 overs a bowler unless the creator picks otherwise; longer games a fifth of the overs.
    const opb = int('overs_per_bowler', overs <= 10 ? Math.min(2, overs) : Math.ceil(overs / 5), 1, overs);
    if (opb == null) return { error: `Overs per bowler must be between 1 and ${overs}.` };
    return { rules: { players_per_side: 11, overs, overs_per_bowler: opb, powerplay_overs: 0, wide_runs: 1, no_ball_runs: 1,
      free_hit: false, last_batter: r.last_batter === true }, squadMax: 11 }; // friendlies: no free hit
  }
  if (sport === 'FOOTBALL') {
    const half = int('half_minutes', 10, 1, 45);
    if (half == null) return { error: 'Each half must be 1-45 minutes.' };
    return { rules: { half_minutes: half, rolling_subs: true, extra_time: false, penalties: false, penalty_kicks: 5 }, squadMax: 15 };
  }
  const event = String(r.event ?? 'DOUBLES').toUpperCase();
  if (!['SINGLES', 'DOUBLES'].includes(event)) return { error: 'Pick singles or doubles.' };
  const ppg = int('points_per_game', sport === 'BADMINTON' ? 21 : 11, 5, 30), games = int('games', sport === 'BADMINTON' ? 3 : 1, 1, 5);
  if (ppg == null) return { error: 'Points per game must be between 5 and 30.' };
  if (games == null || games % 2 === 0) return { error: 'Play 1, 3 or 5 games.' };
  return { rules: { event, points_per_game: ppg, games, win_by_two: true, ...(sport === 'PICKLEBALL' ? { scoring: 'SIDE_OUT' } : {}) },
    squadMax: event === 'SINGLES' ? 2 : 4 };
}
"""

# Shared reads for the match page and actions: the match, both sides with squads and captains, and "I'm in" list.
LOAD_QUICK = (
    "SELECT t.id AS tid, t.code, t.sport, t.name, t.status, t.area, t.scoring_pin, t.organizer_user_id, o.name AS creator_name, "
    "viewer.id AS viewer_id, viewer.name AS viewer_name, viewer.profile_complete AS viewer_ready, d.match_rules, d.squad_max, "
    "m.id AS match_id, m.match_no, m.division_id, m.status AS match_status, DATE_FORMAT(m.scheduled_at, '%Y-%m-%d %H:%i') AS scheduled_at, m.result_text, "
    "m.winner_entry_id, m.event_count, m.home_entry_id, m.away_entry_id, JSON_EXTRACT(m.live, '$.summary') AS summary, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('entry_id', e.id, 'team_id', tm.id, 'team_code', tm.code, 'name', tm.name, 'short', tm.short_name, "
    "'captain_id', (SELECT x.user_id FROM team_members x WHERE x.team_id = tm.id AND x.role = 'CAPTAIN' AND x.status = 'ACTIVE' LIMIT 1), "
    "'players', (SELECT JSON_ARRAYAGG(JSON_OBJECT('user_id', ep.user_id, 'name', COALESCE(u.name, x.guest_name))) "
    "FROM tournament_entry_players ep JOIN team_members x ON x.id = ep.team_member_id LEFT JOIN app_users u ON u.id = x.user_id "
    "WHERE ep.entry_id = e.id))) FROM tournament_entries e JOIN teams tm ON tm.id = e.team_id WHERE e.tournament_id = t.id) AS sides, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('user_id', p.user_id, 'name', pu.name)) FROM quick_match_people p JOIN app_users pu ON pu.id = p.user_id "
    "WHERE p.tournament_id = t.id) AS people, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('match_id', x.id, 'match_no', x.match_no, 'status', x.status, 'events', x.event_count, "
    "'result_text', x.result_text, 'summary', JSON_EXTRACT(x.live, '$.summary'), 'scheduled_at', DATE_FORMAT(x.scheduled_at, '%Y-%m-%d %H:%i'))) "
    "FROM tournament_matches x WHERE x.tournament_id = t.id) AS matches "
    "FROM tournaments t JOIN app_users o ON o.id = t.organizer_user_id JOIN app_users viewer ON viewer.phone = $1 AND viewer.is_active = 1 "
    "JOIN tournament_matches m ON m.id = (SELECT MAX(z.id) FROM tournament_matches z WHERE z.tournament_id = t.id) "
    "JOIN tournament_divisions d ON d.id = m.division_id "
    "WHERE t.code = $2 AND t.kind = 'QUICK'"
)

# Turns the LOAD_QUICK row into sides / people / the viewer's place in the match.
SHAPE = r"""
const parse = v => { if (v == null) return null; if (typeof v === 'object') return v; try { return JSON.parse(v); } catch { return null; } };
const byName = (a, b) => String(a.name).localeCompare(String(b.name));
const sides = (parse(s.sides) || []).map(x => ({ ...x, side: Number(x.entry_id) === Number(s.home_entry_id) ? 'HOME' : 'AWAY',
  captain_id: x.captain_id == null ? null : Number(x.captain_id), players: (parse(x.players) || []).sort(byName) }))
  .sort((a, b) => (a.side === 'HOME' ? 0 : 1) - (b.side === 'HOME' ? 0 : 1));
const people = (parse(s.people) || []).sort(byName);
const me = Number(s.viewer_id), creator = Number(s.organizer_user_id) === me;
const mySide = sides.find(x => x.players.some(p => Number(p.user_id) === me)) || null;
const captainOf = sides.find(x => x.captain_id === me) || null;
// A session can have several matches; actions work on the latest one. Teams change only before it starts.
const matches = (parse(s.matches) || []).map(x => ({ ...x, match_no: Number(x.match_no), events: Number(x.events) })).sort((a, b) => a.match_no - b.match_no);
const sessionOpen = !['CANCELLED', 'COMPLETED'].includes(s.status);
const open = sessionOpen && s.match_status === 'SCHEDULED' && Number(s.event_count) === 0;
const teamName = id => (sides.find(x => Number(x.entry_id) === Number(id)) || {}).name || 'Team';
const fillNames = t => t ? String(t).replace(/\{(\d+)\}/g, (_, id) => teamName(id)) : null;
"""

out = {}

# ───────────── 1. Create a quick match ─────────────
n, c = [], {}
n.append(webhook("v2/quick/create", "POST"))
n.append(code("Check Request", AUTH + RULES + r"""
const sport = str(b.sport).toUpperCase();
if (!""" + SPORTS + r""".includes(sport)) return bad('Pick a sport.');
const home = str(b.home_name) || 'Team A', away = str(b.away_name) || 'Team B';
for (const t of [home, away]) if (t.length < 2 || t.length > 30) return bad('Team names must be 2-30 characters.');
if (home.toLowerCase() === away.toLowerCase()) return bad('Give the two teams different names.');
const ground = str(b.ground).slice(0, 100);
const rr = rulesFor(sport, b.rules);
if (rr.error) return bad(rr.error);
const { rules, squadMax } = rr;
// Start time in India time ("YYYY-MM-DD HH:mm"), from a day ago to 60 days ahead; now if not given.
const india = new Date(Date.now() + 330 * 60e3).toISOString().slice(0, 16).replace('T', ' ');
const at = str(b.scheduled_at) || india;
if (!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(at)) return bad('Pick a valid date and time.');
const diff = (Date.parse(at.replace(' ', 'T') + ':00Z') - Date.parse(india.replace(' ', 'T') + ':00Z')) / 86400e3;
if (!(diff >= -1 && diff <= 60)) return bad('Pick a time within the next 60 days.');
const side = b.my_side == null ? null : String(b.my_side).toUpperCase();
if (side !== null && !['HOME', 'AWAY'].includes(side)) return bad('Pick the team you play for.');
return [{ json: { ok: true, phone: auth.phone, sport, home, away, ground, rules, squadMax, at, side } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load User",
    "SELECT u.id, u.name, u.area, u.city, u.profile_complete, u.jersey_name, u.jersey_number, "
    "(SELECT s.role FROM app_user_sports s WHERE s.user_id = u.id AND s.sport = $2) AS position, "
    "(SELECT COUNT(*) FROM tournaments t WHERE t.organizer_user_id = u.id AND t.kind = 'QUICK' AND t.created_at > NOW() - INTERVAL 1 DAY) AS today "
    "FROM app_users u WHERE u.phone = $1 AND u.is_active = 1",
    "={{ [$json.phone, $json.sport] }}", [660, -100], always=True))
n.append(code("Plan", r"""
const u = $json, r = $('Check Request').first().json;
const fail = (st, m) => [{ json: { ok: false, status: st, body: { success: false, message: m } } }];
if (!u.id) return fail(401, 'Please log in again.');
if (Number(u.profile_complete) !== 1) return fail(409, 'Finish your profile before creating a match.');
if (Number(u.today) >= 20) return fail(429, 'You can create up to 20 quick matches a day.');
const A = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const codeOf = () => Array.from({ length: 6 }, () => A[Math.floor(Math.random() * A.length)]).join('');
const short = name => {
  const words = name.split(' ').map(w => w.replace(/[^A-Za-z0-9]/g, '')).filter(Boolean);
  const s = (words.length > 1 ? words.map(w => w[0]).join('') : (words[0] || 'TEAM')).toUpperCase().slice(0, 4);
  return s.length >= 2 ? s : (s + 'TM').slice(0, 3);
};
const code = codeOf(), pin = String(Math.floor(100000 + Math.random() * 900000));
const uid = Number(u.id), city = u.city || 'Mumbai', area = r.ground || u.area || 'Quick match';
const p = [];
const add = v => { p.push(v); return '$' + p.length; };
const team = (name, v) => `INSERT INTO teams (code, sport, name, short_name, logo_key, area, city, captain_user_id) VALUES (${add(codeOf())}, ${add(r.sport)}, ${add(name)}, ${add(short(name))}, ${add('""" + DEFAULT_TEAM_LOGO + r"""')}, ${add(area)}, ${add(city)}, ${add(uid)}); SET @${v} = LAST_INSERT_ID()`;
const entry = (t, v) => `INSERT INTO tournament_entries (tournament_id, division_id, group_no, team_id, registered_by, status) VALUES (@t, @d, 1, @${t}, ${add(uid)}, 'APPROVED'); SET @${v} = LAST_INSERT_ID()`;
const stmts = [
  'START TRANSACTION',
  `INSERT INTO tournaments (code, organizer_user_id, sport, kind, name, logo_key, category, city, area, start_date, end_date, format, max_teams, squad_min, squad_max, ` +
    `registration_deadline, visibility, status, published_at, fixtures_published_at, scoring_pin) VALUES (${add(code)}, ${add(uid)}, ${add(r.sport)}, 'QUICK', ` +
    `${add(`${r.home} v ${r.away}`)}, ${add('""" + DEFAULT_TEAM_LOGO + r"""')}, 'OTHER', ${add(city)}, ${add(area)}, DATE(${add(r.at)}), DATE(${add(r.at)}), 'LEAGUE', 2, 1, ` +
    `${add(r.squadMax)}, ${add(r.at)} + INTERVAL 7 DAY, 'PRIVATE', 'REGISTRATION_OPEN', NOW(), NOW(), ${add(pin)})`,
  'SET @t = LAST_INSERT_ID()',
  `INSERT INTO tournament_divisions (tournament_id, name, sort_order, format, max_teams, squad_min, squad_max, match_rules, points) VALUES (@t, 'Match', 1, 'LEAGUE', 2, 1, ` +
    `${add(r.squadMax)}, ${add(JSON.stringify(r.rules))}, ${add(JSON.stringify({ win: 2, tie: 1, no_result: 1, loss: 0, tiebreakers: [] }))})`,
  'SET @d = LAST_INSERT_ID()',
  team(r.home, 'th'), team(r.away, 'ta'), entry('th', 'eh'), entry('ta', 'ea'),
  `INSERT INTO tournament_matches (tournament_id, division_id, match_no, stage, group_no, round_no, home_entry_id, away_entry_id, pitch, scheduled_at, status) ` +
    `VALUES (@t, @d, 1, 'GROUP', 1, 1, @eh, @ea, 1, ${add(r.at)}, 'SCHEDULED')`,
];
// Only a creator who plays is in the "I'm in" list (so Shuffle never puts a non-playing creator in a team).
// Playing too: captain of that side and first in its squad.
if (r.side) {
  stmts.push(`INSERT INTO quick_match_people (tournament_id, user_id) VALUES (@t, ${add(uid)})`);
  const tv = r.side === 'HOME' ? '@th' : '@ta', ev = r.side === 'HOME' ? '@eh' : '@ea';
  stmts.push(`INSERT INTO team_members (team_id, user_id, role, position, added_by) VALUES (${tv}, ${add(uid)}, 'CAPTAIN', ${add(u.position || null)}, ${add(uid)})`);
  stmts.push('SET @m = LAST_INSERT_ID()');
  stmts.push(`INSERT INTO tournament_entry_players (entry_id, tournament_id, team_member_id, user_id, jersey_name, jersey_number) VALUES (${ev}, @t, @m, ${add(uid)}, ${add(u.jersey_name || null)}, ${add(u.jersey_number ?? null)})`);
}
stmts.push('COMMIT');
return [{ json: { ok: true, sql: stmts.join('; '), params: p, code } }];""", [880, -100]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1100, -100]))
n.append(mysql("Save", "={{ $json.sql }}", "={{ $json.params }}", [1320, -200], continue_on_error=True))
n.append(code("Build Response", r"""
const msg = String($json.message || $json.error?.message || '');
if ($json.error || /ER_|Duplicate|constraint|syntax/i.test(msg)) return [{ json: { status: 500, body: { success: false, message: 'Could not create the match. Please try again.' } } }];
const code = $('Plan').first().json.code;
return [{ json: { status: 200, body: { success: true, code, link: `https://mypaltan.com/tournament/${code}` } } }];""", [1540, -200]))
n.append(respond([1760, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load User", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load User", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Save", 0); link(c, "Plan OK?", "Respond", 1)
link(c, "Save", "Build Response"); link(c, "Build Response", "Respond")
out['quick_create'] = workflow("QuickCreate026mP", "MyPaltan v2 - Quick Match Create", n, c)

# ───────────── 2. The match page ─────────────
n, c = [], {}
n.append(webhook("v2/quick", "GET"))
n.append(code("Check Request", AUTH + r"""
const code = String($in.query?.code ?? '').toUpperCase();
if (!/^[A-Z0-9]{6}$/.test(code)) return bad('Invalid match link.', 404);
return [{ json: { ok: true, phone: auth.phone, code } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load", LOAD_QUICK, "={{ [$json.phone, $json.code] }}", [660, -100], always=True))
n.append(code("Build Response", r"""
const s = $json;
if (!s.tid) return [{ json: { status: 404, body: { success: false, message: 'Match not found.' } } }];
""" + SHAPE + r"""
const lead = creator || !!captainOf;
const summary = parse(s.summary);
const match = {
  code: s.code, sport: s.sport, name: s.name, status: s.status, ground: s.area, scheduled_at: s.scheduled_at,
  rules: parse(s.match_rules) || {}, squad_max: Number(s.squad_max),
  creator: { user_id: Number(s.organizer_user_id), name: s.creator_name },
  match_id: Number(s.match_id), match_no: Number(s.match_no), match_status: s.match_status, started: Number(s.event_count) > 0,
  session_open: sessionOpen,
  matches: matches.map(x => ({ match_id: Number(x.match_id), match_no: x.match_no, status: x.status, started: x.events > 0,
    result_text: fillNames(x.result_text), summary: parse(x.summary) || null, scheduled_at: x.scheduled_at })),
  result_text: fillNames(s.result_text), winner_entry_id: s.winner_entry_id == null ? null : Number(s.winner_entry_id), summary: summary || null,
  link: `https://mypaltan.com/tournament/${s.code}`,
  sides: sides.map(x => ({ side: x.side, entry_id: Number(x.entry_id), team_code: x.team_code, name: x.name, short: x.short,
    captain: x.captain_id == null ? null : { user_id: x.captain_id, name: (x.players.find(p => Number(p.user_id) === x.captain_id) || {}).name || null },
    players: x.players.map(p => ({ user_id: p.user_id == null ? null : Number(p.user_id), name: p.name })),
    link: `https://mypaltan.com/team/${x.team_code}?t=${s.code}` })),
  people: people.map(p => ({ user_id: Number(p.user_id), name: p.name,
    side: (sides.find(x => x.players.some(q => Number(q.user_id) === Number(p.user_id))) || {}).side || null })),
  me: { user_id: me, is_creator: creator, side: mySide ? mySide.side : null, captain_of: captainOf ? captainOf.side : null,
    in_list: people.some(p => Number(p.user_id) === me) },
  // Only the creator and the captains see the PIN; they pass it to whoever scores.
  ...(lead ? { scoring_pin: s.scoring_pin } : {}),
};
return [{ json: { status: 200, body: { success: true, match } } }];""", [880, -100]))
n.append(respond([1100, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Build Response"); link(c, "Build Response", "Respond")
out['quick_detail'] = workflow("QuickDetail026mP", "MyPaltan v2 - Quick Match Detail", n, c)

# ───────────── 3. Actions: I'm in / leave / pick captain / cancel ─────────────
n, c = [], {}
n.append(webhook("v2/quick/action", "POST"))
n.append(code("Check Request", AUTH + r"""
const code = str(b.code).toUpperCase(), action = str(b.action).toUpperCase();
if (!/^[A-Z0-9]{6}$/.test(code)) return bad('Invalid match link.', 404);
if (!['JOIN', 'LEAVE', 'SET_CAPTAIN', 'ASSIGN', 'SHUFFLE', 'CANCEL', 'NEXT_MATCH', 'END_SESSION'].includes(action)) return bad('Invalid request.');
const side = b.side == null ? null : str(b.side).toUpperCase(), target = b.user_id == null ? null : Number(b.user_id);
if (action === 'SET_CAPTAIN' && (!['HOME', 'AWAY'].includes(side) || !(Number.isInteger(target) && target > 0))) return bad('Pick a captain.');
// ASSIGN: put a player in a team (side HOME / AWAY) or take them out of both (side null).
if (action === 'ASSIGN' && ((side !== null && !['HOME', 'AWAY'].includes(side)) || !(Number.isInteger(target) && target > 0))) return bad('Pick a player.');
// NEXT_MATCH may change the rules for the new match (e.g. more overs); missing ones stay as they were.
const rules = action === 'NEXT_MATCH' && b.rules && typeof b.rules === 'object' ? b.rules : null;
return [{ json: { ok: true, phone: auth.phone, code, action, side, target, rules } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load",
    LOAD_QUICK.replace(" FROM tournaments t JOIN app_users o",
        ", (SELECT CONCAT_WS('|', tu.id, REPLACE(tu.name, '|', ' '), tu.profile_complete, IFNULL(REPLACE(tu.jersey_name, '|', ' '), ''), IFNULL(tu.jersey_number, ''), "
        "IFNULL((SELECT s.role FROM app_user_sports s WHERE s.user_id = tu.id AND s.sport = t.sport), '')) FROM app_users tu WHERE tu.id = $3 AND tu.is_active = 1) AS target "
        "FROM tournaments t JOIN app_users o", 1),
    "={{ [$json.phone, $json.code, $json.target || 0] }}", [660, -100], always=True))
n.append(code("Plan", RULES + r"""
const s = $json, r = $('Check Request').first().json;
const fail = (st, m) => [{ json: { ok: false, status: st, body: { success: false, message: m } } }];
if (!s.tid) return fail(404, 'Match not found.');
""" + SHAPE + r"""
const playing = s.match_status === 'LIVE' || (Number(s.event_count) > 0 && s.match_status !== 'COMPLETED');
const india = new Date(Date.now() + 330 * 60e3).toISOString().slice(0, 16).replace('T', ' ');
const closed = what => fail(409, !sessionOpen ? 'This match has ended.' : s.match_status === 'COMPLETED'
  ? `Tap "Next match" first, then change the ${what}.` : `The match has started, so ${what} cannot change.`);
const p = [], stmts = [];
const add = v => { p.push(v); return '$' + p.length; };
const notify = (user, title, body) => stmts.push(`INSERT INTO notifications (user_id, type, title, body, data) VALUES (${add(user)}, 'ENTRY', ${add(title)}, ${add(body)}, JSON_OBJECT('tournament_code', ${add(s.code)}))`);
let message;
// Team changes (creator only, before kick-off). Quick-match teams belong to this one match, so leaving a team
// removes the member row too.
const captainIds = new Set(sides.map(x => x.captain_id).filter(x => x != null));
const sideOf = u => sides.find(x => x.players.some(q => Number(q.user_id) === Number(u))) || null;
const removeFrom = (x, u) => {
  stmts.push(`DELETE FROM tournament_entry_players WHERE entry_id = ${add(x.entry_id)} AND user_id = ${add(u)}`);
  stmts.push(`DELETE FROM team_members WHERE team_id = ${add(x.team_id)} AND user_id = ${add(u)}`);
};
const addTo = (x, u) => {
  stmts.push(`INSERT INTO team_members (team_id, user_id, role, added_by) VALUES (${add(x.team_id)}, ${add(u)}, 'PLAYER', ${add(me)}) ON DUPLICATE KEY UPDATE status = 'ACTIVE'`);
  stmts.push(`INSERT INTO tournament_entry_players (entry_id, tournament_id, team_member_id, user_id, jersey_name, jersey_number) ` +
    `SELECT ${add(x.entry_id)}, ${add(s.tid)}, tm.id, u.id, u.jersey_name, u.jersey_number FROM team_members tm JOIN app_users u ON u.id = tm.user_id ` +
    `WHERE tm.team_id = ${add(x.team_id)} AND tm.user_id = ${add(u)}`);
};
if (r.action === 'JOIN') {
  if (!sessionOpen) return fail(409, 'This match has ended or was cancelled.');
  if (Number(s.viewer_ready) !== 1) return fail(409, 'Finish your profile first.');
  if (people.some(x => Number(x.user_id) === me)) return [{ json: { ok: false, status: 200, body: { success: true, message: "You're already in." } } }];
  stmts.push(`INSERT IGNORE INTO quick_match_people (tournament_id, user_id) VALUES (${add(s.tid)}, ${add(me)})`);
  if (!creator) notify(Number(s.organizer_user_id), `${s.viewer_name} is in`, `${s.name}: pick captains and make the teams when everyone is in.`);
  message = "You're in! The creator will make the teams.";
} else if (r.action === 'LEAVE') {
  if (!sessionOpen) return fail(409, 'This match has ended.');
  if (creator) return fail(409, "You made this match, so you can't leave it. Cancel it instead.");
  if (mySide && playing) return fail(409, `You're playing for ${mySide.name} right now.`);
  if (captainOf) return fail(409, `You're captain of ${captainOf.name}. Ask the creator to pick another captain first.`);
  stmts.push(`DELETE FROM quick_match_people WHERE tournament_id = ${add(s.tid)} AND user_id = ${add(me)}`);
  message = 'You left the list.';
} else if (r.action === 'CANCEL') {
  if (!creator) return fail(403, 'Only the person who made the match can cancel it.');
  if (!sessionOpen) return fail(409, 'This match has already ended.');
  if (matches.some(x => x.events > 0)) return fail(409, 'A match has been played, so end the session instead.');
  stmts.push(`UPDATE tournaments SET status = 'CANCELLED' WHERE id = ${add(s.tid)}`);
  stmts.push(`UPDATE tournament_matches SET status = 'CANCELLED' WHERE tournament_id = ${add(s.tid)}`);
  message = 'Match cancelled.';
} else if (r.action === 'NEXT_MATCH') {
  if (!creator) return fail(403, 'Only the person who made the match starts the next one.');
  if (!sessionOpen) return fail(409, 'This session has ended.');
  if (playing) return fail(409, `Finish match ${s.match_no} first.`);
  if (s.match_status === 'SCHEDULED') return fail(409, `Match ${s.match_no} hasn't been played yet.`);
  const cur = parse(s.match_rules) || {};
  const rr = r.rules ? rulesFor(s.sport, { ...cur, ...r.rules }) : { rules: cur };
  if (rr.error) return fail(422, rr.error);
  const no = Math.max(0, ...matches.map(x => x.match_no)) + 1;
  // New rules get their own row, so earlier matches keep the rules they were played with.
  const key = o => JSON.stringify(Object.keys(o).sort().map(k => [k, o[k]]));
  if (key(rr.rules) === key(cur)) stmts.push(`SET @d = ${add(s.division_id)}`);
  else {
    stmts.push(`INSERT INTO tournament_divisions (tournament_id, name, sort_order, format, max_teams, squad_min, squad_max, match_rules, points) ` +
      `SELECT tournament_id, ${add('Match ' + no)}, ${add(no)}, format, max_teams, squad_min, squad_max, ${add(JSON.stringify(rr.rules))}, points FROM tournament_divisions WHERE id = ${add(s.division_id)}`);
    stmts.push('SET @d = LAST_INSERT_ID()');
  }
  stmts.push(`INSERT INTO tournament_matches (tournament_id, division_id, match_no, stage, group_no, round_no, home_entry_id, away_entry_id, pitch, scheduled_at, status) ` +
    `VALUES (${add(s.tid)}, @d, ${add(no)}, 'GROUP', 1, ${add(no)}, ${add(s.home_entry_id)}, ${add(s.away_entry_id)}, 1, ${add(india)}, 'SCHEDULED')`);
  message = `Match ${no} is ready. Change the teams if you like, then start it.`;
} else if (r.action === 'END_SESSION') {
  if (!creator) return fail(403, 'Only the person who made the match can end it.');
  if (!sessionOpen) return fail(409, 'This session has already ended.');
  if (playing) return fail(409, `Finish match ${s.match_no} first.`);
  if (!matches.some(x => x.events > 0)) return fail(409, 'No match has been played yet. Cancel it instead.');
  // An unplayed next match is simply removed.
  if (s.match_status === 'SCHEDULED') {
    stmts.push(`DELETE FROM match_players WHERE match_id = ${add(s.match_id)}`);
    stmts.push(`DELETE FROM tournament_matches WHERE id = ${add(s.match_id)} AND event_count = 0`);
  }
  stmts.push(`UPDATE tournaments SET status = 'COMPLETED' WHERE id = ${add(s.tid)}`);
  message = 'Session ended. Well played!';
} else if (r.action === 'ASSIGN') {
  if (!creator) return fail(403, 'Only the person who made the match makes the teams.');
  if (!open) return closed('teams');
  const t = Number(r.target), person = people.find(x => Number(x.user_id) === t), from = sideOf(t), to = r.side ? sides.find(x => x.side === r.side) : null;
  const pname = person?.name || (from?.players.find(q => Number(q.user_id) === t) || {}).name;
  if (!person && !from) return fail(404, 'That person is not on this match any more.');
  if (captainIds.has(t)) return fail(409, `${pname} is a captain. Pick another captain first.`);
  if ((from?.side || null) === (to?.side || null)) return [{ json: { ok: false, status: 200, body: { success: true, message: 'No change.' } } }];
  if (to && to.players.length >= Number(s.squad_max)) return fail(409, `${to.name} is full (${s.squad_max} players).`);
  if (from) removeFrom(from, t);
  if (to) addTo(to, t);
  message = to ? `${pname} is in ${to.name}.` : `${pname} is not in a team now.`;
} else if (r.action === 'SHUFFLE') {
  if (!creator) return fail(403, 'Only the person who made the match makes the teams.');
  if (!open) return closed('teams');
  // Everyone who is in (and anyone already in a team), except the captains, split at random into two even teams.
  const ids = [...new Set([...people.map(x => Number(x.user_id)), ...sides.flatMap(x => x.players.map(q => Number(q.user_id)))])]
    .filter(u => u && !captainIds.has(u));
  if (!ids.length) return fail(409, 'Nobody to put in teams yet. Share the match link first.');
  const size = Object.fromEntries(sides.map(x => [x.side, x.players.filter(q => captainIds.has(Number(q.user_id))).length]));
  for (let i = ids.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [ids[i], ids[j]] = [ids[j], ids[i]]; }
  const plan = {};
  for (const u of ids) {
    const pick = [...sides].sort((a, b) => size[a.side] - size[b.side] || Math.random() - 0.5)[0];
    if (size[pick.side] >= Number(s.squad_max)) break;
    plan[u] = pick; size[pick.side]++;
  }
  for (const u of ids) {
    const from = sideOf(u), to = plan[u] || null;
    if ((from?.side || null) === (to?.side || null)) continue;
    if (from) removeFrom(from, u);
  }
  for (const u of ids) {
    const from = sideOf(u), to = plan[u] || null;
    if (to && (from?.side || null) !== to.side) addTo(to, u);
  }
  const left = ids.length - Object.keys(plan).length;
  message = `Teams shuffled: ${sides.map(x => `${x.name} ${size[x.side]}`).join(', ')}.` + (left ? ` ${left} didn't fit (teams are full).` : '');
} else {
  // SET_CAPTAIN: the creator picks a captain for one side from the people who are in (app or website).
  if (!creator) return fail(403, 'Only the person who made the match picks the captains.');
  if (!open) return closed('captains');
  const side = sides.find(x => x.side === r.side), other = sides.find(x => x.side !== r.side);
  const [tid_, tname, tready, tjn, tjno, tpos] = String(s.target || '').split('|');
  if (!side || !tid_) return fail(404, 'That person is not on this match any more.');
  const t = Number(tid_);
  if (t !== me && !people.some(x => Number(x.user_id) === t)) return fail(409, `${tname} hasn't tapped "I'm in" on this match.`);
  if (other.captain_id === t) return fail(409, `${tname} is captain of ${other.name}.`);
  // A player already in the other team moves to this one.
  if (other.players.some(x => Number(x.user_id) === t)) removeFrom(other, t);
  if (side.captain_id === t) return [{ json: { ok: false, status: 200, body: { success: true, message: `${tname} is already captain.` } } }];
  const inSquad = side.players.some(x => Number(x.user_id) === t);
  if (!inSquad && side.players.length >= Number(s.squad_max)) return fail(409, `${side.name} is full (${s.squad_max} players).`);
  stmts.push(`UPDATE team_members SET role = 'PLAYER' WHERE team_id = ${add(side.team_id)} AND role = 'CAPTAIN'`);
  stmts.push(`INSERT INTO team_members (team_id, user_id, role, position, added_by) VALUES (${add(side.team_id)}, ${add(t)}, 'CAPTAIN', ${add(tpos || null)}, ${add(me)}) ` +
    "ON DUPLICATE KEY UPDATE role = 'CAPTAIN', status = 'ACTIVE'");
  stmts.push(`SET @m = (SELECT id FROM team_members WHERE team_id = ${add(side.team_id)} AND user_id = ${add(t)})`);
  stmts.push(`UPDATE teams SET captain_user_id = ${add(t)} WHERE id = ${add(side.team_id)}`);
  stmts.push(`UPDATE tournament_entries SET registered_by = ${add(t)} WHERE id = ${add(side.entry_id)}`);
  if (!inSquad) stmts.push(`INSERT INTO tournament_entry_players (entry_id, tournament_id, team_member_id, user_id, jersey_name, jersey_number) VALUES (${add(side.entry_id)}, ${add(s.tid)}, @m, ${add(t)}, ${add(tjn || null)}, ${add(tjno === '' || tjno == null ? null : Number(tjno))})`);
  stmts.push(`INSERT IGNORE INTO tournament_scorers (tournament_id, user_id) VALUES (${add(s.tid)}, ${add(t)})`);
  if (t !== me) notify(t, `You're captain of ${side.name}`, `${s.name}: the scoring PIN is on the match page in the app.`);
  message = `${tname} is captain of ${side.name}.`;
}
return [{ json: { ok: true, sql: ['START TRANSACTION', ...stmts, 'COMMIT'].join('; '), params: p, message } }];""", [880, -100]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1100, -100]))
n.append(mysql("Save", "={{ $json.sql }}", "={{ $json.params }}", [1320, -200], continue_on_error=True))
n.append(code("Build Response", r"""
const msg = String($json.message || $json.error?.message || '');
if (msg.includes('uq_tournament_user')) return [{ json: { status: 409, body: { success: false, message: 'That person is already playing for the other team.' } } }];
if ($json.error || /ER_|Duplicate|constraint|syntax/i.test(msg)) return [{ json: { status: 500, body: { success: false, message: 'Could not save. Please try again.' } } }];
return [{ json: { status: 200, body: { success: true, message: $('Plan').first().json.message } } }];""", [1540, -200]))
n.append(respond([1760, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Save", 0); link(c, "Plan OK?", "Respond", 1)
link(c, "Save", "Build Response"); link(c, "Build Response", "Respond")
out['quick_action'] = workflow("QuickAction026mP", "MyPaltan v2 - Quick Match Action", n, c)

# ───────────── 4. My quick matches ─────────────
n, c = [], {}
n.append(webhook("v2/quick/mine", "GET"))
n.append(code("Check Request", AUTH + r"""
return [{ json: { ok: true, phone: auth.phone } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load",
    "SELECT t.code, t.sport, t.name, t.status, t.area, (t.organizer_user_id = u.id) AS is_creator, m.status AS match_status, m.match_no, "
    "(SELECT COUNT(*) FROM tournament_matches z WHERE z.tournament_id = t.id) AS match_count, "
    "DATE_FORMAT(m.scheduled_at, '%Y-%m-%d %H:%i') AS scheduled_at, m.result_text, m.home_entry_id, m.away_entry_id, "
    "JSON_EXTRACT(m.live, '$.summary') AS summary, hm.name AS home_name, aw.name AS away_name "
    "FROM tournaments t JOIN app_users u ON u.phone = $1 "
    "JOIN tournament_matches m ON m.id = (SELECT MAX(z.id) FROM tournament_matches z WHERE z.tournament_id = t.id) "
    "JOIN tournament_entries he ON he.id = m.home_entry_id JOIN teams hm ON hm.id = he.team_id "
    "JOIN tournament_entries ae ON ae.id = m.away_entry_id JOIN teams aw ON aw.id = ae.team_id "
    "WHERE t.kind = 'QUICK' AND (t.organizer_user_id = u.id "
    "OR EXISTS (SELECT 1 FROM quick_match_people p WHERE p.tournament_id = t.id AND p.user_id = u.id) "
    "OR EXISTS (SELECT 1 FROM tournament_entry_players ep WHERE ep.tournament_id = t.id AND ep.user_id = u.id)) "
    "ORDER BY m.scheduled_at DESC LIMIT 50",
    "={{ [$json.phone] }}", [660, -100]))
n.append(code("Build Response", r"""
const parse = v => { if (v == null) return null; if (typeof v === 'object') return v; try { return JSON.parse(v); } catch { return null; } };
const rows = $input.all().map(i => i.json).filter(x => x.code);
const matches = rows.map(x => {
  const sum = parse(x.summary) || {};
  const names = { [x.home_entry_id]: x.home_name, [x.away_entry_id]: x.away_name };
  return { code: x.code, sport: x.sport, name: x.name, status: x.status, ground: x.area, is_creator: Number(x.is_creator) === 1,
    match_status: x.match_status, scheduled_at: x.scheduled_at, match_no: Number(x.match_no), match_count: Number(x.match_count),
    home: { name: x.home_name, score: sum[x.home_entry_id] ?? null }, away: { name: x.away_name, score: sum[x.away_entry_id] ?? null },
    result_text: x.result_text ? String(x.result_text).replace(/\{(\d+)\}/g, (_, id) => names[id] || 'Team') : null };
});
return [{ json: { status: 200, body: { success: true, matches } } }];""", [880, -100]))
n.append(respond([1100, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Build Response"); link(c, "Build Response", "Respond")
mine = workflow("QuickMine0026mPx", "MyPaltan v2 - Quick Match Mine", n, c)
for x in mine['nodes']:
    if x['name'] == 'Load':
        x['alwaysOutputData'] = True
out['quick_mine'] = mine


# ───────────── Patches: keep quick matches out of tournament-only features ─────────────
def load(name):
    return json.load(open(os.path.join(OUT, f'{name}.json')))


def rep(s, a, b):
    if b in s:
        return s  # already patched (the copies in ../workflows/v2 are kept patched)
    assert s.count(a) == 1, (a[:90], s.count(a))
    return s.replace(a, b)


def patch(name, node, field, pairs):
    w = load(name)
    x = next(x for x in w['nodes'] if x['name'] == node)
    v = x['parameters'][field]
    for a, b in pairs:
        v = rep(v, a, b)
    x['parameters'][field] = v
    out[name] = w


patch('tournament_mine', 'Load Mine', 'query', [
    ("WHERE u.phone = $1 UNION ALL", "WHERE u.phone = $1 AND t.kind = 'TOURNAMENT' UNION ALL"),
    ("WHERE e.status IN ('PENDING', 'WAITLISTED', 'APPROVED') AND (ep.id", "WHERE t.kind = 'TOURNAMENT' AND e.status IN ('PENDING', 'WAITLISTED', 'APPROVED') AND (ep.id"),
])
# The app opens the Quick match page when a tournament link turns out to be a quick match.
patch('tournament_detail', 'Load Tournament', 'query', [("SELECT t.id, t.code, t.sport, ", "SELECT t.id, t.code, t.sport, t.kind, ")])
w = out['tournament_detail']
x = next(x for x in w['nodes'] if x['name'] == 'Build Response')
x['parameters']['jsCode'] = rep(x['parameters']['jsCode'], "code: t.code, sport: t.sport, ", "code: t.code, sport: t.sport, kind: t.kind || 'TOURNAMENT', ")
patch('tournament_publish', 'Load State', 'query', [("JOIN tournaments t ON t.code = $2 WHERE u.phone = $1", "JOIN tournaments t ON t.code = $2 AND t.kind = 'TOURNAMENT' WHERE u.phone = $1")])
patch('entry_register', 'Load State', 'query', [("LEFT JOIN teams tm ON tm.code = $4 WHERE t.code = $2", "LEFT JOIN teams tm ON tm.code = $4 WHERE t.code = $2 AND t.kind = 'TOURNAMENT'")])
patch('entry_options', 'Load Options', 'query', [("WHERE t.code = $2 AND t.status <> 'DRAFT'", "WHERE t.code = $2 AND t.kind = 'TOURNAMENT' AND t.status <> 'DRAFT'")])
patch('fixtures_generate', 'Load State', 'query', [("JOIN app_users viewer ON viewer.phone = $1 WHERE t.code = $2", "JOIN app_users viewer ON viewer.phone = $1 WHERE t.code = $2 AND t.kind = 'TOURNAMENT'")])
patch('fixtures_action', 'Load State', 'query', [("AND m.id = $3 WHERE t.code = $2", "AND m.id = $3 WHERE t.code = $2 AND t.kind = 'TOURNAMENT'")])

# The team's captain is the match captain unless the scorer taps C for someone else (quick matches and tournaments).
patch('match_setup', 'Load', 'query', [(
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('entry_id', ep.entry_id, 'member_id', ep.team_member_id)) FROM tournament_entry_players ep ",
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('entry_id', ep.entry_id, 'member_id', ep.team_member_id, "
    "'captain', (SELECT x.role = 'CAPTAIN' FROM team_members x WHERE x.id = ep.team_member_id))) FROM tournament_entry_players ep ")])
patch('match_setup', 'Plan', 'jsCode', [(
    "  if (list.filter(x => x.captain).length > 1 || list.filter(x => x.keeper).length > 1) return fail(422, 'Pick one captain and one wicket-keeper per team.');\n",
    "  if (list.filter(x => x.captain).length > 1 || list.filter(x => x.keeper).length > 1) return fail(422, 'Pick one captain and one wicket-keeper per team.');\n"
    "  // No C tapped: the team's captain leads, if they are playing.\n"
    "  const teamCaptain = Number((squads.find(x => x.entry_id === entry && Number(x.captain) === 1) || {}).member_id);\n"
    "  if (!list.some(x => x.captain) && ids.includes(teamCaptain)) list.forEach(x => { if (Number(x.member_id) === teamCaptain) x.captain = true; });\n")])

for k, w in out.items():
    json.dump(w, open(os.path.join(OUT, f'{k}.json'), 'w'), indent=2)
    print(k, w['id'], len(w['id']), len(w['nodes']), 'nodes')
