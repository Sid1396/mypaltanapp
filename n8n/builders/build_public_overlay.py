"""Builds the live-stream score overlay feed (mypaltan.com/overlay/<CODE>, added to OBS / Prism as a browser source).

  python3 build_public_overlay.py   → writes ../workflows/v2/public_overlay.json

GET v2/public/overlay?code=VPLS07[&match=91]: no login. The tournament's match that is on now (LIVE first, else the most
recently finished one, so the bar shows the result between matches), or the given match, in a small shape for the bar:
teams (name, short, logo), each innings' score, the batters at the crease, the bowler, this over, runs needed and
balls left, and the result / Player of the Match once it ends. Only scores, which are public on the live pages anyway.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_web_registration.py')).read().split('\nout = {}\n')[0])  # node helpers
OUT = os.path.join(HERE, '..', 'workflows', 'v2')

CHECK_JS = r"""
const q = $json.query || {};
const code = String(q.code || '').trim().toUpperCase();
const match = Number(q.match || 0);
if (!/^[A-Z0-9]{6}$/.test(code) || !(Number.isInteger(match) && match >= 0))
  return [{ json: { ok: false, status: 404, body: { success: false, message: 'Tournament not found.' } } }];
return [{ json: { ok: true, code, match } }];
"""

LOAD_SQL = (
    "SELECT t.name AS tname, t.logo_key AS tlogo, t.sport, m.id, m.status, m.label, m.live, "
    "eh.id AS hid, th.name AS hname, th.short_name AS hshort, th.logo_key AS hlogo, "
    "ea.id AS aid, ta.name AS aname, ta.short_name AS ashort, ta.logo_key AS alogo "
    "FROM tournaments t JOIN tournament_matches m ON m.tournament_id = t.id "
    "LEFT JOIN tournament_entries eh ON eh.id = m.home_entry_id LEFT JOIN teams th ON th.id = eh.team_id "
    "LEFT JOIN tournament_entries ea ON ea.id = m.away_entry_id LEFT JOIN teams ta ON ta.id = ea.team_id "
    "WHERE t.code = $1 AND t.status <> 'DRAFT' AND m.live IS NOT NULL "
    "AND (($2 = 0 AND m.status IN ('LIVE', 'COMPLETED')) OR m.id = $2) "
    "ORDER BY (m.status = 'LIVE') DESC, m.updated_at DESC LIMIT 1"
)

BUILD_JS = r"""
const r = $('Load').all().map(i => i.json).find(x => x && x.id);
if (!r) return [{ json: { status: 200, body: { success: true, match: null } } }];
const b2 = $('Authorize B2').isExecuted ? $('Authorize B2').first().json : {};
const dl = b2?.apiInfo?.storageApi?.downloadUrl;
const tokenOf = node => { try { return $(node).isExecuted ? $(node).first().json.authorizationToken : null; } catch { return null; } };
const tokens = { 'tournament_assets/': tokenOf('Assets Link'), 'team_assets/': tokenOf('Team Link') };
const sign = k => {
  const tok = k && tokens[Object.keys(tokens).find(p => k.startsWith(p))];
  return dl && tok ? `${dl}/file/mypaltan-profile-photos/${k.split('/').map(encodeURIComponent).join('/')}?Authorization=${tok}` : null;
};
const live = typeof r.live === 'string' ? JSON.parse(r.live) : (r.live || {});
const team = (id, name, short, logo) => id ? { entry_id: id, name, short: short || String(name || '').slice(0, 3).toUpperCase(), logo_url: sign(logo) } : null;
const bat = b => b ? { name: b.name, runs: b.runs, balls: b.balls } : null;
const c = live.current || null;
const match = {
  id: r.id, status: r.status, label: r.label || null, sport: r.sport,
  tournament: { name: r.tname, logo_url: sign(r.tlogo) },
  home: team(r.hid, r.hname, r.hshort, r.hlogo), away: team(r.aid, r.aname, r.ashort, r.alogo),
  overs_limit: live.overs_limit ?? null,
  innings: (live.innings || []).map(i => ({ no: i.no, batting: i.batting_entry_id, runs: i.runs, wickets: i.wickets, overs: i.overs,
    target: i.target ?? null, run_rate: i.run_rate ?? null, complete: !!i.complete })),
  current: c ? {
    innings: c.innings, striker: bat(c.striker), non_striker: bat(c.non_striker),
    bowler: c.bowler ? { name: c.bowler.name, wickets: c.bowler.wickets, runs: c.bowler.runs, overs: c.bowler.overs } : null,
    this_over: c.this_over || [], free_hit: !!c.free_hit, need: c.need ?? null, balls_left: c.balls_left ?? null, required_rate: c.required_rate ?? null,
  } : null,
  last: (live.commentary || [])[0] ? { symbol: live.commentary[0].symbol, text: live.commentary[0].text } : null,
  result: live.result || null,
  potm: live.potm ? { name: live.potm.name, reason: live.potm.reason || null } : null,
  // Football: the score line (the bar shows it when the sport is football).
  score: live.score || null, phase: live.phase || null,
};
return [{ json: { status: 200, body: { success: true, match } } }];
"""

n, c = [], {}
n.append(webhook("v2/public/overlay", "GET"))
n.append(code("Check Request", CHECK_JS, [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load", LOAD_SQL, "={{ [$json.code, $json.match] }}", [660, -100], always=True))
n.append(code("B2 Credentials", B2_AUTH, [880, -100]))
au = http("Authorize B2", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [1100, -100])
au["onError"] = "continueRegularOutput"
n.append(au)
for name, prefix, y in [("Assets Link", "tournament_assets/", -100), ("Team Link", "team_assets/", 60)]:
    x = http(name, "POST", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_download_authorization",
             [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}"), ("Content-Type", "application/json")], [1320, y],
             json_body="={{ JSON.stringify({ bucketId: '" + BUCKET_ID + "', fileNamePrefix: '" + prefix + "', validDurationInSeconds: 86400 }) }}")
    x["onError"] = "continueRegularOutput"
    n.append(x)
n.append(node("Build Response", "n8n-nodes-base.code", 2, [1540, -100], {"jsCode": BUILD_JS}))
n.append(respond([1760, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "B2 Credentials"); link(c, "B2 Credentials", "Authorize B2"); link(c, "Authorize B2", "Assets Link")
link(c, "Assets Link", "Team Link"); link(c, "Team Link", "Build Response"); link(c, "Build Response", "Respond")
w = workflow("PubOverlay026mP", "MyPaltan v2 - Public Overlay", n, c)
json.dump(w, open(os.path.join(OUT, 'public_overlay.json'), 'w'), indent=2)
print('public_overlay', w['id'], len(w['nodes']), 'nodes')
