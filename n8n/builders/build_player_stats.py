"""Builds the player career stats and rankings workflow (app: Home → My stats, Rankings).

  python3 build_player_stats.py   → writes ../workflows/v2/player_stats.json

GET v2/players/stats?sport=CRICKET|FOOTBALL&kind=TOURNAMENT|QUICK&period=ALL|YEAR|90D&city=&block=&age=ALL|U16|U19|19_35|35P
                    &gender=ALL|MALE|FEMALE&ball=ALL|TENNIS|LEATHER&min=3&brief=1&player=<user id>

Every completed match of the sport and kind (tournament and quick-match stats are never mixed), each scorecard player
mapped to their MyPaltan account (guest players have none and are left out). Batting, bowling and football numbers use
the same code as the tournament stats (copied from tournament_stats.json); cricket's overall points are formula E with
par = runs per legal ball over the matches counted. Ranked players need `min` matches (default 3). The player asking
always gets their own row and ranks, ranked or not. brief=1 leaves out the lists (Home card).
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_web_registration.py')).read().split('\nout = {}\n')[0])  # node helpers
APP_AUTH = open(os.path.join(HERE, '_app_auth.js')).read()
OUT = os.path.join(HERE, '..', 'workflows', 'v2')

# The tournament stats' own calculations, so career numbers match the tournament pages exactly.
_stats = json.load(open(os.path.join(OUT, 'tournament_stats.json')))
_js = next(n['parameters']['jsCode'] for n in _stats['nodes'] if 'function computeStats' in n['parameters'].get('jsCode', ''))
SHARED_JS = _js[_js.index('const parseJ ='):_js.index('\n', _js.index('const parseJ ='))] + '\n' + \
    _js[_js.index('function computeStats'):_js.index('function leaderboards')] + \
    _js[_js.index('const POTM_POINTS'):_js.index('function footballLeaderboards')]

CHECK_JS = APP_AUTH + r"""
const auth = verifyToken($json.headers);
if (!auth.ok) return [{ json: { ok: false, status: 401, body: { success: false, message: auth.error } } }];
const q = $json.query || {};
const pick = (v, list, d) => (list.includes(String(v || '').toUpperCase()) ? String(v).toUpperCase() : d);
const text = v => String(v ?? '').trim().slice(0, 100);
return [{ json: { ok: true, phone: auth.phone,
  sport: pick(q.sport, ['CRICKET', 'FOOTBALL'], 'CRICKET'), kind: pick(q.kind, ['TOURNAMENT', 'QUICK'], 'TOURNAMENT'),
  period: pick(q.period, ['ALL', 'YEAR', '90D'], 'ALL'), age: pick(q.age, ['ALL', 'U16', 'U19', '19_35', '35P'], 'ALL'),
  gender: pick(q.gender, ['ALL', 'MALE', 'FEMALE'], 'ALL'), ball: pick(q.ball, ['ALL', 'TENNIS', 'LEATHER'], 'ALL'),
  city: text(q.city), block: text(q.block), min: Math.min(20, Math.max(1, Number(q.min) || 3)), brief: q.brief === '1',
  player: Number.isInteger(Number(q.player)) && Number(q.player) > 0 ? Number(q.player) : null } }];
"""

LOAD_SQL = (
    "SELECT viewer.id AS viewer_id, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('id', m.id, 'at', DATE_FORMAT(COALESCE(m.ended_at, m.scheduled_at), '%Y-%m-%d'), "
    "  'tid', t.id, 'tcode', t.code, 'tname', t.name, 'tstart', DATE_FORMAT(t.start_date, '%Y-%m-%d'), "
    "  'teams', JSON_OBJECT(CAST(COALESCE(m.home_entry_id, 0) AS CHAR), th.name, CAST(COALESCE(m.away_entry_id, 0) AS CHAR), ta.name), "
    "  'ball', JSON_UNQUOTE(JSON_EXTRACT(d.match_rules, '$.ball_type')), 'innings', JSON_EXTRACT(m.live, '$.innings'), "
    "  'player_stats', JSON_EXTRACT(m.live, '$.player_stats'), 'potm', JSON_EXTRACT(m.live, '$.potm'))) "
    " FROM tournament_matches m JOIN tournaments t ON t.id = m.tournament_id JOIN tournament_divisions d ON d.id = m.division_id "
    " LEFT JOIN tournament_entries he ON he.id = m.home_entry_id LEFT JOIN teams th ON th.id = he.team_id "
    " LEFT JOIN tournament_entries ae ON ae.id = m.away_entry_id LEFT JOIN teams ta ON ta.id = ae.team_id "
    " WHERE m.status = 'COMPLETED' AND m.live IS NOT NULL AND t.sport = $2 AND t.kind = $3) AS matches, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('m', ev.match_id, 's', ev.seq, 'type', ev.type, 'data', ev.data)) "
    " FROM match_events ev JOIN tournament_matches xm ON xm.id = ev.match_id JOIN tournaments xt ON xt.id = xm.tournament_id "
    " WHERE xm.status = 'COMPLETED' AND xt.sport = 'CRICKET' AND $2 = 'CRICKET' AND xt.kind = $3 "
    " AND ev.type IN ('BALL', 'START_INNINGS', 'NEW_BOWLER', 'UNDO')) AS events, "
    "(SELECT JSON_OBJECTAGG(tm.id, tm.user_id) FROM team_members tm JOIN teams te ON te.id = tm.team_id "
    " WHERE tm.user_id IS NOT NULL AND te.sport = $2) AS members, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('id', u.id, 'name', u.name, 'gender', u.gender, "
    "  'age', TIMESTAMPDIFF(YEAR, u.birthdate, CURDATE()), 'block', u.block, 'district', u.district, 'city', u.city, 'photo_key', u.photo_key, 'jersey_name', u.jersey_name, 'jersey_number', u.jersey_number, "
    "  'role', (SELECT s.role FROM app_user_sports s WHERE s.user_id = u.id AND s.sport = $2 LIMIT 1), "
    "  'batting_hand', (SELECT s.batting_hand FROM app_user_sports s WHERE s.user_id = u.id AND s.sport = $2 LIMIT 1), "
    "  'bowling_style', (SELECT s.bowling_style FROM app_user_sports s WHERE s.user_id = u.id AND s.sport = $2 LIMIT 1))) "
    " FROM app_users u WHERE u.id IN (SELECT tm.user_id FROM team_members tm JOIN teams te ON te.id = tm.team_id "
    " WHERE tm.user_id IS NOT NULL AND te.sport = $2)) AS users "
    "FROM app_users viewer WHERE viewer.phone = $1"
)

BUILD_JS = SHARED_JS + r"""
const f = $('Check Request').first().json;
const t = $('Load').first().json;
// Player photos: one download link for the whole profile_photos/ folder (no photos if B2 is unreachable).
const b2 = (() => { try { return $('Authorize B2').first().json || {}; } catch { return {}; } })();
const photoTok = (() => { try { return $('Photo Link').first().json.authorizationToken || null; } catch { return null; } })();
const dl = b2.apiInfo ? b2.apiInfo.storageApi.downloadUrl : null;
const photoOf = k => (k && dl && photoTok ? `${dl}/file/mypaltan-profile-photos/${k.split('/').map(encodeURIComponent).join('/')}?Authorization=${photoTok}` : null);
const cricket = f.sport === 'CRICKET';
const memberUser = parseJ(t.members) || {};
const users = new Map((parseJ(t.users) || []).map(u => [Number(u.id), u]));
const userOf = id => (memberUser[id] == null ? null : Number(memberUser[id]));
const me = Number(t.viewer_id);

// Matches counted: period and ball.
const day = 864e5, now = Date.now();
const from = f.period === 'YEAR' ? `${new Date().getFullYear()}-01-01` : f.period === '90D' ? new Date(now - 90 * day).toISOString().slice(0, 10) : '';
const raw = (parseJ(t.matches) || []).filter(m => (!from || String(m.at || '') >= from) && (f.ball === 'ALL' || m.ball === f.ball));
const kept = new Set(raw.map(m => m.id));

// Par for formula E: runs per legal ball over every innings counted.
let parRuns = 0, parBalls = 0;
const matches = raw.map(m => {
  const innings = (parseJ(m.innings) || []).map(inn => {
    parRuns += Number(inn.runs) || 0; parBalls += Number(inn.legal_balls) || 0;
    const mine = list => (list || []).map(x => ({ ...x, id: userOf(x.id) })).filter(x => x.id != null);
    return { ...inn, batting: mine(inn.batting), bowling: mine(inn.bowling) };
  });
  const potm = parseJ(m.potm);
  return { id: m.id, tid: m.tid, tcode: m.tcode, tname: m.tname, tstart: m.tstart, at: m.at, teams: parseJ(m.teams) || {},
    division_id: 0, status: 'COMPLETED', innings,
    player_stats: (parseJ(m.player_stats) || []).map(r => ({ ...r, id: userOf(r.id) })).filter(r => r.id != null),
    potm: potm ? { ...potm, id: userOf(potm.id) } : null };
});
const par = parBalls ? parRuns / parBalls : 2;

// Catches and run outs from the ball-by-ball (as the tournament's Player of the Series does).
const fielding = new Map();
if (cricket) {
  const byMatch = new Map();
  for (const e of parseJ(t.events) || []) { if (!kept.has(e.m)) continue; if (!byMatch.has(e.m)) byMatch.set(e.m, []); byMatch.get(e.m).push(e); }
  for (const evs of byMatch.values()) {
    const live = [];
    for (const e of evs.sort((a, b) => a.s - b.s)) { if (e.type === 'UNDO') live.pop(); else live.push(e); }
    let bowler = null;
    for (const e of live) {
      const d = parseJ(e.data) || {};
      if (e.type === 'START_INNINGS') bowler = d.bowler ?? null;
      if (e.type === 'NEW_BOWLER') bowler = d.id ?? null;
      const w = e.type === 'BALL' ? d.wicket : null;
      if (!w || !['CAUGHT', 'STUMPED', 'RUN_OUT'].includes(w.how)) continue;
      const u = userOf(w.fielder ?? (w.how === 'CAUGHT' ? bowler : null));
      if (u == null) continue;
      const x = fielding.get(u) || { catches: 0, run_outs: 0 };
      if (w.how === 'CAUGHT') x.catches++; else x.run_outs++;
      fielding.set(u, x);
    }
  }
}

// One row per player.
const potms = new Map();
for (const m of matches) if (m.potm && m.potm.id != null) potms.set(m.potm.id, (potms.get(m.potm.id) || 0) + 1);
const base = cricket ? computeStats(matches) : computeFootballStats(matches);
const rows = base.map(p => {
  const u = users.get(p.member_id) || {};
  const r = { user_id: p.member_id, name: u.name || p.name || 'Player', area: [u.block, u.city || u.district].filter(Boolean).join(', ') || null,
    photo_url: photoOf(u.photo_key) };
  if (!cricket) return { ...r, matches: matches.filter(m => m.player_stats.some(x => x.id === p.member_id)).length,
    goals: p.goals, assists: p.assists, clean_sheets: p.clean_sheets, yellow: p.yellow, red: p.red, potm: p.potm, points: p.points };
  const fl = fielding.get(p.member_id) || { catches: 0, run_outs: 0 };
  const bat = p.innings ? p.runs + 0.25 * (p.runs - p.balls * par) : 0;
  const bowl = 4 * p.wickets + (p.legal_balls ? 0.75 * (p.legal_balls * par - p.runs_conceded) : 0);
  return { ...r, matches: p.matches, innings: p.innings, runs: p.runs, balls: p.balls, fours: p.fours, sixes: p.sixes, outs: p.outs,
    highest: p.highest, fifties: p.fifties, average: p.average, strike_rate: p.strike_rate,
    overs: p.overs, legal_balls: p.legal_balls, runs_conceded: p.runs_conceded, wickets: p.wickets, economy: p.economy, best: p.best,
    catches: fl.catches, run_outs: fl.run_outs, potm: potms.get(p.member_id) || 0,
    points: Math.round(bat + bowl + fl.catches + fl.run_outs) };
});

// Player filters: area, age, gender. Area choices come from players with stats.
const ageOk = a => f.age === 'ALL' || (a != null && (f.age === 'U16' ? a < 16 : f.age === 'U19' ? a < 19 : f.age === '19_35' ? a >= 19 && a <= 35 : a > 35));
const pass = r => {
  const u = users.get(r.user_id) || {};
  if (f.city && u.city !== f.city && u.district !== f.city) return false;
  if (f.block && u.block !== f.block) return false;
  if (f.gender !== 'ALL' && u.gender !== f.gender) return false;
  return ageOk(u.age == null ? null : Number(u.age));
};
const cities = [...new Set(rows.map(r => (users.get(r.user_id) || {}).city).filter(Boolean))].sort();
const blocks = [...new Set(rows.filter(r => !f.city || (users.get(r.user_id) || {}).city === f.city)
  .map(r => (users.get(r.user_id) || {}).block).filter(Boolean))].sort();

const ranked = rows.filter(r => pass(r) && r.matches >= f.min);
const sorts = cricket ? {
  overall: [r => r.points !== 0, (a, b) => b.points - a.points || b.runs - a.runs],
  batting: [r => r.runs > 0, (a, b) => b.runs - a.runs || (b.strike_rate || 0) - (a.strike_rate || 0)],
  bowling: [r => r.wickets > 0, (a, b) => b.wickets - a.wickets || (a.economy ?? 99) - (b.economy ?? 99)],
  fielding: [r => r.catches + r.run_outs > 0, (a, b) => (b.catches + b.run_outs) - (a.catches + a.run_outs) || b.catches - a.catches],
} : {
  overall: [r => r.points > 0, (a, b) => b.points - a.points || b.goals - a.goals],
  goals: [r => r.goals > 0, (a, b) => b.goals - a.goals || b.assists - a.assists],
  assists: [r => r.assists > 0, (a, b) => b.assists - a.assists || b.goals - a.goals],
  clean_sheets: [r => r.clean_sheets > 0, (a, b) => b.clean_sheets - a.clean_sheets],
};
const lists = {}, myRanks = {}, theirRanks = {};
for (const [k, [keep, sort]] of Object.entries(sorts)) {
  const all = ranked.filter(keep).sort(sort).map((r, i) => ({ rank: i + 1, ...r }));
  if (!f.brief) lists[k] = all.slice(0, 50);
  const mine = all.find(r => r.user_id === me);
  myRanks[k] = mine ? mine.rank : null;
  const theirs = f.player ? all.find(r => r.user_id === f.player) : null;
  theirRanks[k] = theirs ? theirs.rank : null;
}
// One player's page (?player=): their row and ranks, and who they are even without matches of this kind.
let player = null;
if (f.player) {
  const u = users.get(f.player);
  const row = rows.find(r => r.user_id === f.player) || null;
  // The tournaments (or quick-match sessions) they played: team, matches and their numbers in each, latest first.
  const byT = new Map();
  for (const m of matches) {
    let team = null, played = false;
    const x = { runs: 0, balls: 0, wickets: 0, goals: 0, assists: 0 };
    if (cricket) {
      for (const inn of m.innings) {
        for (const b of inn.batting || []) if (b.id === f.player) { played = true; x.runs += b.runs || 0; x.balls += b.balls || 0; team = inn.batting_entry_id; }
        for (const b of inn.bowling || []) if (b.id === f.player) { played = true; x.wickets += b.wickets || 0; team = team ?? inn.bowling_entry_id; }
      }
    } else {
      for (const r of m.player_stats) if (r.id === f.player) { played = true; x.goals += r.goals || 0; x.assists += r.assists || 0; team = r.team; }
    }
    if (!played) continue;
    const k = m.tid;
    if (!byT.has(k)) byT.set(k, { code: m.tcode, name: m.tname, start: m.tstart, last: m.at, team: null, matches: 0, runs: 0, balls: 0, wickets: 0, goals: 0, assists: 0, potm: 0 });
    const tt = byT.get(k);
    tt.matches++; for (const key of Object.keys(x)) tt[key] += x[key];
    if (m.potm && m.potm.id === f.player) tt.potm++;
    if (!tt.team && team != null) tt.team = m.teams[String(team)] || null;
    if (String(m.at || '') > String(tt.last || '')) tt.last = m.at;
  }
  const played = [...byT.values()].sort((a, b) => String(b.last || '').localeCompare(String(a.last || '')));
  player = u ? { user_id: f.player, tournaments: played, name: u.name || 'Player', area: [u.block, u.city || u.district].filter(Boolean).join(', ') || null,
    photo_url: photoOf(u.photo_key), jersey_name: u.jersey_name || null, jersey_number: u.jersey_number ?? null, role: u.role || null,
    batting_hand: u.batting_hand || null, bowling_style: u.bowling_style || null,
    row, ranks: theirRanks, ranked: !!row && pass(row) && row.matches >= f.min } : null;
}
const mine = rows.find(r => r.user_id === me) || null;
return [{ json: { status: 200, body: { success: true, sport: f.sport, kind: f.kind, min: f.min, par: Math.round(par * 100) / 100,
  matches: matches.length, ranked: ranked.length, filters: { cities, blocks },
  me: { row: mine, ranks: myRanks, ranked: !!mine && pass(mine) && mine.matches >= f.min }, player, lists } } }];
"""

n, c = [], {}
n.append(webhook("v2/players/stats", "GET"))
n.append(code("Check Request", CHECK_JS, [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load", LOAD_SQL, "={{ [$json.phone, $json.sport, $json.kind] }}", [660, -100], always=True))
n.append(node("Build Response", "n8n-nodes-base.code", 2, [1540, -100], {"jsCode": BUILD_JS}))
n.append(respond([1760, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
n.append(code("B2 Credentials", B2_AUTH, [880, -100]))
au = http("Authorize B2", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [1100, -100])
au["onError"] = "continueRegularOutput"
n.append(au)
pl = http("Photo Link", "POST", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_download_authorization",
          [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}"), ("Content-Type", "application/json")], [1320, -100],
          json_body="={{ JSON.stringify({ bucketId: '" + BUCKET_ID + "', fileNamePrefix: 'profile_photos/', validDurationInSeconds: 86400 }) }}")
pl["onError"] = "continueRegularOutput"
n.append(pl)
link(c, "Load", "B2 Credentials"); link(c, "B2 Credentials", "Authorize B2"); link(c, "Authorize B2", "Photo Link"); link(c, "Photo Link", "Build Response")
link(c, "Build Response", "Respond")
w = workflow("PlayerStats026mP", "MyPaltan v2 - Player Stats", n, c)
w["settings"]["saveDataSuccessExecution"] = "none"
json.dump(w, open(os.path.join(OUT, 'player_stats.json'), 'w'), indent=2)
print('player_stats', w['id'], len(w['nodes']), 'nodes')
