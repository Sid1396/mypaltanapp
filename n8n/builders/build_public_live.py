"""Builds the public, read-only live pages' endpoints for tournaments registered on mypaltan.com
(mypaltan.com/live/<slug>, e.g. football-fiesta): fixtures + points tables, player stats, and one match.

  python3 build_public_live.py
    → writes ../workflows/v2/public_live.json, public_live_stats.json, public_live_match.json

Each one is the app's own workflow (fixtures_get / tournament_stats / match_detail, kept in sync with live) with:
  - no login: the tournament comes from its web-link slug, and nothing shows until the fixtures are published;
  - a privacy filter: players are shown as "First L." (they are children), with no photos, birthdates or phones,
    and nothing only the organiser or scorer should see;
  - a 5-second cache for the pages' automatic refreshes, so a crowd watching doesn't load the database or storage;
    a page load or a manual refresh (?fresh=1) skips it and always gets the latest score.
So the website always shows exactly what the app shows.
"""
import copy
import json
import os
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_web_registration.py')).read().split('\nout = {}\n')[0])  # node helpers, rate(), ORIGINS


def load(name):
    return json.load(open(os.path.join(OUT, f'{name}.json')))


def rep(s, a, b):
    assert s.count(a) == 1, a[:80]
    return s.replace(a, b)


SHORT_JS = r"""
// Children's names on public pages: first name + last initial ("Aarav Shah" → "Aarav S.").
const short = n => { const w = String(n || '').trim().split(/\s+/).filter(Boolean); return w.length < 2 ? (w[0] || '') : `${w[0]} ${w[w.length - 1][0].toUpperCase()}.`; };
"""

CACHE_CHECK = r"""
// Automatic refreshes share one copy for 5 seconds so a crowd watching doesn't each hit the database.
// A page load or manual refresh sends fresh=1 and always reads the latest score (still rate limited).
const cache = $getWorkflowStaticData('global');
const key = %s;
const hit = (cache.c || {})[key];
if (hit && Date.now() - hit.at < 5000 && String(($in.query || {}).fresh || '') !== '1') return [{ json: { ok: false, status: 200, body: hit.body } }];
"""

CACHE_STORE = r"""
const cache = $getWorkflowStaticData('global');
const now = Date.now();
cache.c = Object.fromEntries(Object.entries(cache.c || {}).filter(([, v]) => now - v.at < 60000));
if (out.status === 200 && out.body && out.body.success) cache.c[%s] = { at: now, body: out.body };
return [{ json: out }];
"""


def make_public(src_name, wid, name, path, check_js, cache_key_js, filter_js, sql_edits, params, code_edits=()):
    w = copy.deepcopy(load(src_name))
    w.update(id=wid, name=name, active=False)
    nodes = {n['name']: n for n in w['nodes']}
    hook = nodes['Webhook']
    hook['webhookId'] = str(uuid.uuid4())
    hook['parameters'].update(path=path, httpMethod='GET')
    hook['parameters'].setdefault('options', {})['allowedOrigins'] = ORIGINS
    check_name = 'Check Login' if 'Check Login' in nodes else 'Check Request'
    js = 'const $in = $input.first().json;\n' + rate(3000) + (CACHE_CHECK % cache_key_js) + check_js
    nodes[check_name]['parameters']['jsCode'] = js
    load_node = [n for n in w['nodes'] if n['type'].endswith('mySql')][0]
    q = load_node['parameters']['query']
    for a, b in sql_edits:
        q = rep(q, a, b)
    load_node['parameters']['query'] = q
    load_node['parameters']['options']['queryReplacement'] = params
    for node_name, a, b in code_edits:
        nodes[node_name]['parameters']['jsCode'] = rep(nodes[node_name]['parameters']['jsCode'], a, b)
    # Privacy filter + cache between Build Response and Respond.
    br, resp = nodes['Build Response'], nodes['Respond']
    filt = {"id": str(uuid.uuid4()), "name": "Public Filter", "type": "n8n-nodes-base.code", "typeVersion": 2,
            "position": [br['position'][0] + 220, br['position'][1]],
            "parameters": {"jsCode": "const out = JSON.parse(JSON.stringify($input.first().json));\n" + SHORT_JS +
                           "if (out.status === 200 && out.body && out.body.success) {\n  // The match endpoint wraps its data in body.match.\n  const b = out.body.match || out.body;\n" + filter_js + "\n}\n" +
                           (CACHE_STORE % cache_key_js.replace('$in.query', "$('%s').first().json._q" % check_name))}}
    w['nodes'].append(filt)
    for src, conns in w['connections'].items():
        for outs in conns.get('main', []):
            for t in outs:
                if t['node'] == 'Respond' and src == 'Build Response':
                    t['node'] = 'Public Filter'
    w['connections']['Public Filter'] = {"main": [[{"node": "Respond", "type": "main", "index": 0}]]}
    for k in ('shared', 'tags', 'activeVersionId', 'versionCounter', 'triggerCount', 'versionMetadata', 'activeVersion', 'versionId'):
        w.pop(k, None)
    return w


SLUG_CHECK = r"""
const q = $in.query || {};
const slug = String(q.slug || '').toLowerCase();
if (!/^[a-z0-9-]{2,40}$/.test(slug)) return [{ json: { ok: false, status: 404, body: { success: false, message: 'This page does not exist.' } } }];
count();
// No login: the viewer is nobody, so only published fixtures are shown.
return [{ json: { ok: true, phone: '', code: slug, slug, _q: { slug } } }];"""

WEB_TOURNAMENT = "WHERE t.id = (SELECT l.tournament_id FROM tournament_web_links l WHERE l.slug = $2) AND t.status <> 'DRAFT'"

# Cricket Player of the Series (app and website): the app's player-of-the-match points (formula E) over the whole
# tournament, with par = the division's runs per legal ball; ties go to more runs, then more wickets. Catches and run outs aren't in the
# scorecards, so they come from the match events (replayed with UNDO, as the app does).
SERIES_SQL = (
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('m', ev.match_id, 'd', xm.division_id, 's', ev.seq, 'type', ev.type, 'data', ev.data)) "
    " FROM match_events ev JOIN tournament_matches xm ON xm.id = ev.match_id "
    " WHERE xm.tournament_id = t.id AND xm.status IN ('LIVE', 'COMPLETED') AND t.sport = 'CRICKET') AS events, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('id', ep.team_member_id, 'entry', ep.entry_id, 'name', COALESCE(pu.name, x.guest_name))) "
    " FROM tournament_entry_players ep JOIN team_members x ON x.id = ep.team_member_id LEFT JOIN app_users pu ON pu.id = x.user_id "
    " WHERE ep.tournament_id = t.id AND t.sport = 'CRICKET') AS members")

SERIES_JS = r"""
// ── Cricket Player of the Series: player-of-the-match points over the whole tournament ──
const fielding = new Map(); // `${division}:${member}` → { catches, run_outs }
{
  const byMatch = new Map();
  for (const e of parseJ(t.events) || []) { if (!byMatch.has(e.m)) byMatch.set(e.m, []); byMatch.get(e.m).push(e); }
  for (const evs of byMatch.values()) {
    const kept = [];
    for (const e of evs.sort((a, b) => a.s - b.s)) { if (e.type === 'UNDO') kept.pop(); else kept.push(e); }
    let bowler = null;
    for (const e of kept) {
      const data = parseJ(e.data) || {};
      if (e.type === 'START_INNINGS') bowler = data.bowler ?? null;
      if (e.type === 'NEW_BOWLER') bowler = data.id ?? null;
      const w = e.type === 'BALL' ? data.wicket : null;
      if (!w) continue;
      const fid = w.fielder ?? (w.how === 'CAUGHT' ? bowler : null);
      if (fid == null || !['CAUGHT', 'STUMPED', 'RUN_OUT'].includes(w.how)) continue;
      const k = `${e.d}:${fid}`;
      const f = fielding.get(k) || { catches: 0, run_outs: 0 };
      if (w.how === 'CAUGHT') f.catches++; else f.run_outs++;
      fielding.set(k, f);
    }
  }
}
const memberOf = new Map((parseJ(t.members) || []).map(m => [Number(m.id), m]));
function seriesOf(div, players, leaders, done) {
  const byId = new Map(players.map(p => [p.member_id, { ...p }]));
  for (const [k, f] of fielding) {
    const [d, id] = k.split(':').map(Number);
    if (d !== div || byId.has(id)) continue;
    const m = memberOf.get(id) || {};
    byId.set(id, { division_id: div, member_id: id, name: m.name || 'Player', entry_id: m.entry ?? null, runs: 0, wickets: 0 });
  }
  const plural = (n, w) => `${n} ${w}${n === 1 ? '' : w === 'catch' ? 'es' : 's'}`;
  const balls = players.reduce((s, p) => s + (p.legal_balls || 0), 0);
  const par = balls ? players.reduce((s, p) => s + (p.runs_conceded || 0), 0) / balls : 2;
  const rows = [...byId.values()].map(p => {
    const f = fielding.get(`${div}:${p.member_id}`) || { catches: 0, run_outs: 0 };
    // Formula E (as the app's Player of the Match), par = the division's runs per legal ball.
    const bat = p.innings ? (p.runs || 0) + 0.25 * ((p.runs || 0) - (p.balls || 0) * par) : 0;
    const bowl = 4 * (p.wickets || 0) + (p.legal_balls ? 0.75 * (p.legal_balls * par - (p.runs_conceded || 0)) : 0);
    const points = Math.round(bat + bowl + f.catches + f.run_outs);
    const reason = [p.innings && (p.runs || !p.wickets) ? `${p.runs} runs` : null, p.wickets ? plural(p.wickets, 'wicket') : null,
      f.catches ? plural(f.catches, 'catch') : null, f.run_outs ? plural(f.run_outs, 'run out') : null].filter(Boolean).join(' · ');
    return { member_id: p.member_id, name: p.name, entry_id: p.entry_id, runs: p.runs || 0, wickets: p.wickets || 0,
      catches: f.catches, run_outs: f.run_outs, points, reason };
  }).filter(p => p.points > 0).sort((a, b) => b.points - a.points || b.runs - a.runs || b.wickets - a.wickets);
  leaders.series_points = rows.slice(0, 10);
  return rows.length ? { ...rows[0], final: done } : null;
}
"""

SERIES_EDITS = (
    [(" AS my_entries FROM tournaments t", " AS my_entries, " + SERIES_SQL + " FROM tournaments t")],
    [("Build Response", "const divisions = (parseJ(t.divisions)", SERIES_JS + "const divisions = (parseJ(t.divisions)"),
     ("Build Response", "const pott = football && leaders.mvp.length ? { ...leaders.mvp[0], final: done } : null;",
      "const pott = football ? (leaders.mvp.length ? { ...leaders.mvp[0], final: done } : null) : seriesOf(d.id, players, leaders, done);")])

# The app's own stats workflow gets Player of the Series too (once: the repo copy keeps it); the public one copies it.
stats_src = load('tournament_stats')
if 'seriesOf(' not in json.dumps(stats_src):
    nodes = {n['name']: n for n in stats_src['nodes']}
    sql_node = [n for n in stats_src['nodes'] if n['type'].endswith('mySql')][0]
    for a, b in SERIES_EDITS[0]:
        sql_node['parameters']['query'] = rep(sql_node['parameters']['query'], a, b)
    for node_name, a, b in SERIES_EDITS[1]:
        nodes[node_name]['parameters']['jsCode'] = rep(nodes[node_name]['parameters']['jsCode'], a, b)
    json.dump(stats_src, open(os.path.join(OUT, 'tournament_stats.json'), 'w'), indent=2)
    print('tournament_stats', stats_src['id'], 'with Player of the Series')

out = {}

out['public_live'] = make_public(
    'fixtures_get', 'PubLiveFx026mPxQ', 'MyPaltan v2 - Public Live Fixtures', 'v2/public/live', SLUG_CHECK,
    "'f:' + String(($in.query || {}).slug || '')",
    r"""  for (const k of ['is_owner', 'my_entry_ids', 'teams_changed']) delete b[k];
  for (const d of b.divisions || []) delete d.settings;""",
    [("WHERE t.code = $2 AND t.status <> 'DRAFT'", WEB_TOURNAMENT)],
    "={{ [$json.phone, $json.code] }}",
    # The page shows a cricket or football table.
    [("Build Response", "body: { success: true, code: t.code,", "body: { success: true, sport: t.sport, code: t.code,")])

out['public_live_stats'] = make_public(
    'tournament_stats', 'PubLiveSt026mPxR', 'MyPaltan v2 - Public Live Stats', 'v2/public/live/stats', SLUG_CHECK,
    "'s:' + String(($in.query || {}).slug || '')",
    r"""  delete b.my_entry_ids;
  const clean = p => { if (p && typeof p === 'object') { p.name = short(p.name); delete p.photo_url; delete p.user_id; } return p; };
  for (const d of b.divisions || []) {
    (d.players || []).forEach(clean);
    for (const list of Object.values(d.leaders || {})) if (Array.isArray(list)) list.forEach(clean);
    if (d.player_of_tournament) clean(d.player_of_tournament);
  }""",
    [("WHERE t.code = $2 AND t.status <> 'DRAFT'", WEB_TOURNAMENT)],
    "={{ [$json.phone, $json.code] }}")

out['public_live_match'] = make_public(
    'match_detail', 'PubLiveMt026mPxS', 'MyPaltan v2 - Public Live Match', 'v2/public/live/match', r"""
const q = $in.query || {};
const slug = String(q.slug || '').toLowerCase(), id = Number(q.id);
if (!/^[a-z0-9-]{2,40}$/.test(slug) || !(Number.isInteger(id) && id > 0)) return [{ json: { ok: false, status: 404, body: { success: false, message: 'Match not found.' } } }];
count();
return [{ json: { ok: true, phone: '', id, slug, light: false, _q: { slug, id } } }];""",
    "'m:' + String(($in.query || {}).slug || '') + ':' + String(($in.query || {}).id || '')",
    r"""  for (const k of ['is_owner', 'can_score', 'scoring_locked_by', 'events', 'scorer_name', 'scorer_idle', 'scorer']) delete b[k];
  // Every full name in this match → "First L.", including inside timeline texts like "GOAL · Aarav Shah".
  const names = new Map();
  const add = n => { if (n && String(n).trim().includes(' ')) names.set(String(n).trim(), short(n)); };
  for (const side of [b.home, b.away]) for (const p of (side && side.squad) || []) add(p.name);
  for (const p of b.lineups || []) add(p.name);
  const live = b.live && typeof b.live === 'object' ? b.live : null;
  for (const p of (live && live.player_stats) || []) add(p.name);
  if (live && live.potm) add(live.potm.name);
  // Cricket scorecard: batters, bowlers, wickets, commentary and the current batters and bowler.
  const cur = live && live.current;
  for (const inn of (live && live.innings) || []) {
    for (const p of [...(inn.batting || []), ...(inn.bowling || []), ...(inn.fall_of_wickets || [])]) add(p.name);
    for (const n of inn.yet_to_bat || []) add(n);
  }
  for (const c of (live && live.commentary) || []) { add(c.batter); add(c.bowler); }
  if (cur) for (const p of [cur.striker, cur.non_striker, cur.bowler]) if (p) add(p.name);
  const fix = s => { if (typeof s !== 'string') return s; let t = s; for (const [f, sh] of names) t = t.split(f).join(sh); return t; };
  for (const side of [b.home, b.away]) if (side && side.squad) side.squad = side.squad.map(p => ({ member_id: p.member_id, name: short(p.name), jersey_number: p.jersey_number ?? null }));
  if (b.lineups) b.lineups = b.lineups.map(p => ({ ...p, name: short(p.name), user_id: undefined }));
  if (live) {
    for (const e of live.timeline || []) { if (e.player) e.player = short(e.player); if (e.assist) e.assist = short(e.assist); e.text = fix(e.text); }
    for (const p of live.player_stats || []) p.name = short(p.name);
    if (live.potm) live.potm.name = short(live.potm.name);
    for (const inn of live.innings || []) {
      for (const p of inn.batting || []) { p.name = short(p.name); p.how_out = fix(p.how_out); }
      for (const p of [...(inn.bowling || []), ...(inn.fall_of_wickets || [])]) p.name = short(p.name);
      inn.yet_to_bat = (inn.yet_to_bat || []).map(short);
    }
    for (const c of live.commentary || []) { c.batter = short(c.batter); c.bowler = short(c.bowler); c.text = fix(c.text); }
    if (cur) for (const p of [cur.striker, cur.non_striker, cur.bowler]) if (p) p.name = short(p.name);
    live.result = fix(live.result);
  }
  b.result_text = fix(b.result_text);""",
    [("WHERE m.id = $2", "WHERE m.id = $2 AND t.id = (SELECT l.tournament_id FROM tournament_web_links l WHERE l.slug = $3)")],
    "={{ [$json.phone, $json.id, $json.slug] }}")

for k, w in out.items():
    json.dump(w, open(os.path.join(OUT, f'{k}.json'), 'w'), indent=2)
    print(k, w['id'], len(w['id']), len(w['nodes']), 'nodes')
