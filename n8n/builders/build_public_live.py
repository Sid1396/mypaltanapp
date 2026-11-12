"""Builds the public, read-only live pages' endpoints for tournaments registered on mypaltan.com
(mypaltan.com/live/<slug>, e.g. football-fiesta): fixtures + points tables, player stats, and one match.

  python3 build_public_live.py
    → writes ../workflows/v2/public_live.json, public_live_stats.json, public_live_match.json

Each one is the app's own workflow (fixtures_get / tournament_stats / match_detail, kept in sync with live) with:
  - no login: the tournament comes from its web-link slug, and nothing shows until the fixtures are published;
  - a privacy filter: players are shown as "First L." (they are children), with no photos, birthdates or phones,
    and nothing only the organiser or scorer should see;
  - a 20-second cache per request, so a crowd of parents refreshing doesn't load the database or storage.
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
// Serve a fresh copy for 20 seconds so many parents refreshing at once don't each hit the database.
const cache = $getWorkflowStaticData('global');
const key = %s;
const hit = (cache.c || {})[key];
if (hit && Date.now() - hit.at < 20000) return [{ json: { ok: false, status: 200, body: hit.body } }];
"""

CACHE_STORE = r"""
const cache = $getWorkflowStaticData('global');
const now = Date.now();
cache.c = Object.fromEntries(Object.entries(cache.c || {}).filter(([, v]) => now - v.at < 60000));
if (out.status === 200 && out.body && out.body.success) cache.c[%s] = { at: now, body: out.body };
return [{ json: out }];
"""


def make_public(src_name, wid, name, path, check_js, cache_key_js, filter_js, sql_edits, params):
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
    # Privacy filter + cache between Build Response and Respond.
    br, resp = nodes['Build Response'], nodes['Respond']
    filt = {"id": str(uuid.uuid4()), "name": "Public Filter", "type": "n8n-nodes-base.code", "typeVersion": 2,
            "position": [br['position'][0] + 220, br['position'][1]],
            "parameters": {"jsCode": "const out = JSON.parse(JSON.stringify($input.first().json));\n" + SHORT_JS +
                           "if (out.status === 200 && out.body && out.body.success) {\n  const b = out.body;\n" + filter_js + "\n}\n" +
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

out = {}

out['public_live'] = make_public(
    'fixtures_get', 'PubLiveFx026mPxQ', 'MyPaltan v2 - Public Live Fixtures', 'v2/public/live', SLUG_CHECK,
    "'f:' + String(($in.query || {}).slug || '')",
    r"""  for (const k of ['is_owner', 'my_entry_ids', 'teams_changed']) delete b[k];
  for (const d of b.divisions || []) delete d.settings;""",
    [("WHERE t.code = $2 AND t.status <> 'DRAFT'", WEB_TOURNAMENT)],
    "={{ [$json.phone, $json.code] }}")

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
  const fix = s => { if (typeof s !== 'string') return s; let t = s; for (const [f, sh] of names) t = t.split(f).join(sh); return t; };
  for (const side of [b.home, b.away]) if (side && side.squad) side.squad = side.squad.map(p => ({ member_id: p.member_id, name: short(p.name), jersey_number: p.jersey_number ?? null }));
  if (b.lineups) b.lineups = b.lineups.map(p => ({ ...p, name: short(p.name), user_id: undefined }));
  if (live) {
    for (const e of live.timeline || []) { if (e.player) e.player = short(e.player); if (e.assist) e.assist = short(e.assist); e.text = fix(e.text); }
    for (const p of live.player_stats || []) p.name = short(p.name);
    if (live.potm) live.potm.name = short(live.potm.name);
    live.result = fix(live.result);
  }
  b.result_text = fix(b.result_text);""",
    [("WHERE m.id = $2", "WHERE m.id = $2 AND t.id = (SELECT l.tournament_id FROM tournament_web_links l WHERE l.slug = $3)")],
    "={{ [$json.phone, $json.id, $json.slug] }}")

for k, w in out.items():
    json.dump(w, open(os.path.join(OUT, f'{k}.json'), 'w'), indent=2)
    print(k, w['id'], len(w['id']), len(w['nodes']), 'nodes')
