"""Builds the "All tournaments" list (app: Tournaments → All).

  python3 build_tournaments_all.py   → writes ../workflows/v2/tournaments_all.json

GET v2/tournaments/all?sport=ALL|CRICKET|…&status=ALL|LIVE|OPEN|DONE&offset=0: every listed (approved, PUBLIC)
tournament of any status: live first, then upcoming (soonest first), then completed (most recent first). 20 a page.
Quick matches, drafts and unlisted tournaments are left out. The first page (status ALL) also has the featured leagues
("Registrations open soon" cards, as on Home) in `featured`.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_web_registration.py')).read().split('\nout = {}\n')[0])  # node helpers
APP_AUTH = open(os.path.join(HERE, '_app_auth.js')).read()
OUT = os.path.join(HERE, '..', 'workflows', 'v2')
PAGE = 20

CHECK_JS = APP_AUTH + r"""
const auth = verifyToken($json.headers);
if (!auth.ok) return [{ json: { ok: false, status: 401, body: { success: false, message: auth.error } } }];
const q = $json.query || {};
const sport = String(q.sport || 'ALL').toUpperCase();
const status = String(q.status || 'ALL').toUpperCase();
if (!['ALL', 'CRICKET', 'FOOTBALL', 'BADMINTON', 'PICKLEBALL', 'VOLLEYBALL', 'KABADDI', 'BASKETBALL', 'TENNIS', 'BOX_CRICKET'].includes(sport) || !['ALL', 'LIVE', 'OPEN', 'DONE'].includes(status))
  return [{ json: { ok: false, status: 422, body: { success: false, message: 'Unknown filter.' } } }];
const offset = Math.max(0, Math.min(5000, parseInt(q.offset, 10) || 0));
return [{ json: { ok: true, phone: auth.phone, sport, status, offset } }];
"""

# Stage: 0 live, 1 upcoming / registration, 2 completed. Upcoming soonest first; completed latest first.
STAGE = ("CASE WHEN t.status = 'LIVE' THEN 0 WHEN t.status = 'COMPLETED' OR t.end_date < CURDATE() THEN 2 ELSE 1 END")
LOAD_SQL = (
    "SELECT t.code, t.name, t.sport, t.logo_key, t.entry_type, t.status, t.area, t.city, "
    "DATE_FORMAT(t.start_date, '%Y-%m-%d') AS start_date, DATE_FORMAT(t.end_date, '%Y-%m-%d') AS end_date, "
    f"{STAGE} AS stage, "
    "(t.status = 'REGISTRATION_OPEN' AND (t.registration_deadline IS NULL OR t.registration_deadline >= CONVERT_TZ(NOW(), '+00:00', '+05:30'))) AS reg_open, "
    "(SELECT COUNT(*) FROM tournament_entries e WHERE e.tournament_id = t.id AND e.status = 'APPROVED') AS teams, "
    # Champions: the winner of each division's final (the only match in its last knockout round).
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('division', d.name, 'team', tm.name, 'logo_key', tm.logo_key)) "
    " FROM tournament_matches fm JOIN tournament_entries we ON we.id = fm.winner_entry_id JOIN teams tm ON tm.id = we.team_id "
    " JOIN tournament_divisions d ON d.id = fm.division_id "
    " WHERE fm.tournament_id = t.id AND fm.stage = 'KNOCKOUT' AND fm.status = 'COMPLETED' "
    " AND fm.round_no = (SELECT MAX(x.round_no) FROM tournament_matches x WHERE x.division_id = fm.division_id AND x.stage = 'KNOCKOUT') "
    " AND (SELECT COUNT(*) FROM tournament_matches x WHERE x.division_id = fm.division_id AND x.stage = 'KNOCKOUT' AND x.round_no = fm.round_no) = 1) AS champions, "
    "(SELECT IF(COUNT(*) > 1, CONCAT(COUNT(*), ' divisions'), CASE MIN(v.format) WHEN 'LEAGUE' THEN 'League' WHEN 'KNOCKOUT' THEN 'Knockout' ELSE 'Groups + knockout' END) "
    " FROM tournament_divisions v WHERE v.tournament_id = t.id) AS format_tag "
    "FROM tournaments t WHERE t.visibility = 'PUBLIC' AND COALESCE(t.kind, 'TOURNAMENT') <> 'QUICK' AND t.status <> 'DRAFT' "
    "AND ($1 = 'ALL' OR t.sport = $1) "
    "AND ($2 = 'ALL' OR ($2 = 'LIVE' AND t.status = 'LIVE') "
    f" OR ($2 = 'OPEN' AND t.status = 'REGISTRATION_OPEN') OR ($2 = 'DONE' AND {STAGE} = 2)) "
    f"ORDER BY stage, IF({STAGE} = 2, -TO_DAYS(t.end_date), TO_DAYS(t.start_date)), t.id DESC "
    f"LIMIT {PAGE + 1} OFFSET "
)
# The offset is a whole number checked in Check Request (0-5000), so it goes straight into the query.
LOAD_SQL = "=" + LOAD_SQL + "{{ $json.offset }}"
# Featured leagues ("Registrations open soon" cards the MyPaltan team adds, as on Home), with the first page of All.
LOAD_SQL += (
    "; SELECT 'featured' AS _set, f.slug, f.name, f.sport, f.logo_url, f.logo_key, DATE_FORMAT(f.start_date, '%Y-%m-%d') AS start_date, "
    "f.area, f.city, f.tags, f.status, f.entry_type, (SELECT COUNT(*) FROM featured_interest fi JOIN app_users iu ON iu.id = fi.user_id "
    "WHERE fi.slug = f.slug AND iu.phone = $3) AS interested FROM featured_tournaments f "
    "WHERE f.is_active = 1 AND ($1 = 'ALL' OR f.sport = $1) AND $2 = 'ALL' AND {{ $json.offset }} = 0 ORDER BY f.sort_order, f.id"
)

BUILD_JS = r"""
const all = $('Load').all().map(i => i.json).filter(Boolean);
const rows = all.filter(r => r.code && r._set !== 'featured');
const r0 = $('Check Request').first().json;
const b2 = $('Authorize B2').isExecuted ? $('Authorize B2').first().json : {};
const dl = b2?.apiInfo?.storageApi?.downloadUrl;
const tokenOf = node => { try { return $(node).isExecuted ? $(node).first().json.authorizationToken : null; } catch { return null; } };
const tokens = { 'tournament_assets/': tokenOf('Assets Link'), 'team_assets/': tokenOf('Team Link'), 'league_logos/': tokenOf('League Link') };
const sign = k => {
  const tok = k && tokens[Object.keys(tokens).find(p => k.startsWith(p))];
  return dl && tok ? `${dl}/file/mypaltan-profile-photos/${k.split('/').map(encodeURIComponent).join('/')}?Authorization=${tok}` : null;
};
const parseJ = v => { if (v == null) return null; if (typeof v === 'object') return v; try { return JSON.parse(v); } catch { return null; } };
const PAGE = """ + str(PAGE) + r""";
const tournaments = rows.slice(0, PAGE).map(r => ({
  code: r.code, name: r.name, sport: r.sport, logo_url: sign(r.logo_key), entry_type: r.entry_type || 'OPEN', status: r.status,
  stage: ['LIVE', 'UPCOMING', 'COMPLETED'][Number(r.stage)] || 'UPCOMING', registration_open: Number(r.reg_open) === 1,
  area: r.area || null, city: r.city || null, start_date: r.start_date, end_date: r.end_date, teams: Number(r.teams || 0), format: r.format_tag || null,
  champions: Number(r.stage) === 2 ? (parseJ(r.champions) || []).map(x => ({ division: x.division, team: x.team, logo_url: sign(x.logo_key) })) : [],
}));
const tagsOf = t => { if (Array.isArray(t)) return t; try { return JSON.parse(t || '[]'); } catch { return []; } };
const featured = all.filter(r => r._set === 'featured').map(r => ({
  slug: r.slug, code: null, name: r.name, sport: r.sport, logo_url: sign(r.logo_key) || r.logo_url || null, start_date: r.start_date || null,
  area: r.area || null, city: r.city, tags: tagsOf(r.tags), status: r.status, interested: Number(r.interested || 0) > 0,
  entry_type: r.entry_type || 'OPEN',
}));
return [{ json: { status: 200, body: { success: true, tournaments, featured, next_offset: rows.length > PAGE ? r0.offset + PAGE : null } } }];
"""

n, c = [], {}
n.append(webhook("v2/tournaments/all", "GET"))
n.append(code("Check Request", CHECK_JS, [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load", LOAD_SQL, "={{ [$json.sport, $json.status, $json.phone] }}", [660, -100], always=True))
n.append(code("B2 Credentials", B2_AUTH, [880, -100]))
au = http("Authorize B2", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [1100, -100])
au["onError"] = "continueRegularOutput"
n.append(au)
al = http("Assets Link", "POST", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_download_authorization",
          [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}"), ("Content-Type", "application/json")], [1320, -100],
          json_body="={{ JSON.stringify({ bucketId: '" + BUCKET_ID + "', fileNamePrefix: 'tournament_assets/', validDurationInSeconds: 86400 }) }}")
al["onError"] = "continueRegularOutput"
n.append(al)
tl = http("Team Link", "POST", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_download_authorization",
          [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}"), ("Content-Type", "application/json")], [1430, 60],
          json_body="={{ JSON.stringify({ bucketId: '" + BUCKET_ID + "', fileNamePrefix: 'team_assets/', validDurationInSeconds: 86400 }) }}")
tl["onError"] = "continueRegularOutput"
n.append(tl)
ll = http("League Link", "POST", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_download_authorization",
          [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}"), ("Content-Type", "application/json")], [1430, 220],
          json_body="={{ JSON.stringify({ bucketId: '" + BUCKET_ID + "', fileNamePrefix: 'league_logos/', validDurationInSeconds: 86400 }) }}")
ll["onError"] = "continueRegularOutput"
n.append(ll)
n.append(node("Build Response", "n8n-nodes-base.code", 2, [1540, -100], {"jsCode": BUILD_JS}))
n.append(respond([1760, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "B2 Credentials"); link(c, "B2 Credentials", "Authorize B2"); link(c, "Authorize B2", "Assets Link"); link(c, "Assets Link", "Team Link"); link(c, "Team Link", "League Link"); link(c, "League Link", "Build Response")
link(c, "Build Response", "Respond")
w = workflow("TourAll2026mPx", "MyPaltan v2 - Tournaments All", n, c)
from add_b2_cache import add_b2_cache  # reuse B2 image links for 20 h (see add_b2_cache.py)
add_b2_cache(w)
json.dump(w, open(os.path.join(OUT, 'tournaments_all.json'), 'w'), indent=2)
print('tournaments_all', w['id'], len(w['nodes']), 'nodes')
