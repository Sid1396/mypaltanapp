"""Builds the home-banner workflows (portal tab mypaltan.com/approvals → Home banners, and banner stats from the app).

  python3 build_home_banners.py [live_home.json]
    → writes ../workflows/v2/staff_home_banners.json, staff_home_banner_save.json, banner_track.json
      and, when the live Home workflow export is given, ../workflows/v2/home.json patched for image banners.

Only the MyPaltan owner (superadmin) manages banners. Images go to the private bucket under home_banners/ and are
shown through signed links. Times are typed in India time and stored in UTC like the rest of the database.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_staff_tournament.py')).read().split('\nout = {}\n')[0])  # helpers + staff_gate
APP_AUTH = open(os.path.join(HERE, '_app_auth.js')).read()

SIGN_JS = r"""
const b2 = (() => { try { return $('Authorize B2').first().json || {}; } catch { return {}; } })();
const dl = b2.apiInfo ? b2.apiInfo.storageApi.downloadUrl : null;
const tok = n => { try { return $(n).first().json.authorizationToken || null; } catch { return null; } };
const tokens = { 'home_banners/': tok('Banner Link'), 'league_logos/': tok('Logo Link') };
const sign = k => { if (!k || !dl) return null; const p = Object.keys(tokens).find(x => k.startsWith(x)); const t = p && tokens[p];
  return t ? `${dl}/file/""" + BUCKET_NAME + r"""/${k.split('/').map(encodeURIComponent).join('/')}?Authorization=${t}` : null; };
"""


def b2_links(n, c, after, x, y, then, prefixes):
    """Authorize B2, then one download link per folder; failures leave images empty instead of failing the page."""
    n.append(code("B2 Credentials", B2_AUTH, [x, y]))
    au = http("Authorize B2", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [x + 200, y])
    au["onError"] = "continueRegularOutput"
    n.append(au)
    prev = "Authorize B2"
    for i, (name, prefix) in enumerate(prefixes):
        h = http(name, "POST", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_download_authorization",
                 [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}"), ("Content-Type", "application/json")], [x + 400 + 200 * i, y],
                 json_body="={{ JSON.stringify({ bucketId: '" + BUCKET_ID + "', fileNamePrefix: '" + prefix + "', validDurationInSeconds: 86400 }) }}")
        h["onError"] = "continueRegularOutput"
        n.append(h)
        link(c, prev, name)
        prev = name
    link(c, after, "B2 Credentials"); link(c, "B2 Credentials", "Authorize B2"); link(c, prev, then)


out = {}

# ───────────── 1. All banners with views / taps, plus tournaments to link to ─────────────
n, c = [], {}
n.append(webhook("v2/staff/home-banners", "GET"))
n.append(code("Check Token", STAFF_AUTH + "\nreturn [{ json: { ok: true, sid: auth.sid } }];", [220, 0]))
n.append(iff("Token OK?", "={{ $json.ok }}", [440, 0]))
staff_gate(n, c, "Token OK?", 660)
c["Token OK?"]["main"] = [[{"node": "Load Staff", "type": "main", "index": 0}], [{"node": "Respond", "type": "main", "index": 0}]]
n.append(mysql("Load Banners",
    "SELECT 'banner' AS _set, b.id, b.kind, b.title, b.subtitle, b.badge, b.image_key, b.theme, b.link_type, b.link_value, b.sort_order, b.is_active, "
    "DATE_FORMAT(CONVERT_TZ(b.starts_at, '+00:00', '+05:30'), '%Y-%m-%dT%H:%i') AS starts_at, DATE_FORMAT(CONVERT_TZ(b.ends_at, '+00:00', '+05:30'), '%Y-%m-%dT%H:%i') AS ends_at, "
    "(b.starts_at IS NOT NULL AND b.starts_at > NOW()) AS upcoming, (b.ends_at IS NOT NULL AND b.ends_at <= NOW()) AS ended, "
    "COALESCE((SELECT SUM(s.views) FROM home_banner_daily_stats s WHERE s.banner_id = b.id), 0) AS views, "
    "COALESCE((SELECT SUM(s.taps) FROM home_banner_daily_stats s WHERE s.banner_id = b.id), 0) AS taps, "
    "COALESCE((SELECT SUM(s.views) FROM home_banner_daily_stats s WHERE s.banner_id = b.id AND s.day > CURDATE() - INTERVAL 7 DAY), 0) AS views_7d, "
    "COALESCE((SELECT SUM(s.taps) FROM home_banner_daily_stats s WHERE s.banner_id = b.id AND s.day > CURDATE() - INTERVAL 7 DAY), 0) AS taps_7d, "
    "DATE_FORMAT(CONVERT_TZ(COALESCE(b.updated_at, b.created_at), '+00:00', '+05:30'), '%Y-%m-%d %H:%i') AS changed "
    "FROM home_banners b ORDER BY b.sort_order, b.id; "
    "SELECT 'tournament' AS _set, t.code AS value, t.name, DATE_FORMAT(t.start_date, '%Y-%m-%d') AS start_date FROM tournaments t "
    "WHERE t.visibility = 'PUBLIC' AND t.status IN ('REGISTRATION_OPEN', 'REGISTRATION_CLOSED', 'FIXTURES_READY', 'LIVE') AND t.end_date >= CURDATE(); "
    "SELECT 'tournament' AS _set, f.slug AS value, f.name, DATE_FORMAT(f.start_date, '%Y-%m-%d') AS start_date FROM featured_tournaments f WHERE f.is_active = 1",
    "", [1320, -200], always=True))
link(c, "Allowed?", "Load Banners", 0); link(c, "Allowed?", "Respond", 1)
b2_links(n, c, "Load Banners", 1540, -200, "Build Response", [("Banner Link", "home_banners/"), ("Logo Link", "league_logos/")])
n.append(code("Build Response", SIGN_JS + r"""
const rows = $('Load Banners').all().map(i => i.json).filter(r => r && r._set);
const banners = rows.filter(r => r._set === 'banner').map(r => ({
  id: r.id, kind: r.kind, title: r.title, subtitle: r.subtitle || null, badge: r.badge || null, theme: r.theme,
  image_url: sign(r.image_key), has_image: !!r.image_key, link_type: r.link_type, link_value: r.link_value || null,
  is_active: Number(r.is_active) === 1, starts_at: r.starts_at || null, ends_at: r.ends_at || null,
  state: Number(r.is_active) !== 1 ? 'OFF' : Number(r.ended) === 1 ? 'ENDED' : Number(r.upcoming) === 1 ? 'SCHEDULED' : 'LIVE',
  views: Number(r.views), taps: Number(r.taps), views_7d: Number(r.views_7d), taps_7d: Number(r.taps_7d), changed: r.changed,
}));
const tournaments = rows.filter(r => r._set === 'tournament').map(r => ({ value: r.value, name: r.name, start_date: r.start_date }))
  .sort((a, b) => String(a.start_date).localeCompare(String(b.start_date)));
return [{ json: { status: 200, body: { success: true, banners, tournaments } } }];""", [2400, -200]))
n.append(respond([2620, 0]))
link(c, "Build Response", "Respond")
link(c, "Webhook", "Check Token"); link(c, "Check Token", "Token OK?")
out['staff_home_banners'] = workflow("StfHomeBn026mPxM", "MyPaltan v2 - Staff Home Banners", n, c)

# ───────────── 2. Add / edit (with picture), switch on-off, move up-down, delete ─────────────
n, c = [], {}
n.append(webhook("v2/staff/home-banners/save", "POST"))
n.append(code("Check Request", STAFF_AUTH + SIZE_HELPER + r"""
const b = $in.body || {};
const bad = m => [{ json: { ok: false, status: 422, body: { success: false, message: m } } }];
const str = v => String(v ?? '').trim().replace(/\s+/g, ' ');
const action = str(b.action).toUpperCase();
if (!['SAVE', 'TOGGLE', 'MOVE', 'DELETE'].includes(action)) return bad('Invalid request.');
const id = b.id === undefined || b.id === '' || b.id === null ? 0 : Number(b.id);
if (!Number.isInteger(id) || id < 0 || (action !== 'SAVE' && !id)) return bad('Invalid banner.');
const base = { ok: true, sid: auth.sid, action, id };
if (action === 'MOVE') {
  const dir = str(b.direction).toUpperCase();
  if (!['UP', 'DOWN'].includes(dir)) return bad('Invalid request.');
  return [{ json: { ...base, dir } }];
}
if (action !== 'SAVE') return [{ json: base }];

const kind = str(b.kind).toUpperCase();
if (!['CARD', 'IMAGE'].includes(kind)) return bad('Choose image banner or text card.');
const title = str(b.title);
if (title.length < 2 || title.length > 80) return bad(kind === 'IMAGE' ? 'Enter a name for this banner, e.g. the sponsor (2-80 characters).' : 'Enter a title (2-80 characters).');
const subtitle = kind === 'CARD' ? str(b.subtitle) : '';
const badge = kind === 'CARD' ? str(b.badge) : '';
if (subtitle.length > 160) return bad('The short line can be up to 160 characters.');
if (badge.length > 30) return bad('The label can be up to 30 characters.');
const theme = str(b.theme).toUpperCase() === 'DARK' ? 'DARK' : 'ORANGE';

const link_type = str(b.link_type).toUpperCase() || 'NONE';
if (!['NONE', 'TOURNAMENT', 'URL'].includes(link_type)) return bad('Choose what happens on tap.');
let link_value = null;
if (link_type === 'URL') {
  let u = String(b.link_value ?? '').trim();
  if (u && !/^[a-z][a-z0-9+.-]*:\/\//i.test(u)) u = 'https://' + u;
  // n8n's code sandbox has no URL class, so check the shape by hand: http(s)://host.tld[:port][/path?query#hash]
  const m = u.match(/^(https?):\/\/([a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,})(:\d{1,5})?([/?#][^\s<>"]*)?$/i);
  if (!m || u.length > 255) return bad('Enter a valid website link, e.g. https://sponsor.com');
  link_value = m[1].toLowerCase() === 'http' ? u.replace(/^http:/i, 'https:') : u;
} else if (link_type === 'TOURNAMENT') {
  const v = String(b.link_value ?? '').trim();
  if (!/^[A-Z0-9]{6}$/.test(v) && !/^[a-z0-9-]{2,40}$/.test(v)) return bad('Choose the tournament to open.');
  link_value = v;
}

// The portal sends India time as YYYY-MM-DDTHH:mm; the database keeps UTC.
const when = (v, label) => {
  const s = String(v ?? '').trim();
  if (!s) return { v: null };
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(s)) return { error: `Check the ${label} date.` };
  const d = new Date(`${s}:00+05:30`);
  return isNaN(d) ? { error: `Check the ${label} date.` } : { v: d.toISOString().slice(0, 19).replace('T', ' '), t: d.getTime() };
};
const st = when(b.starts_at, 'show from'), en = when(b.ends_at, 'show until');
if (st.error || en.error) return bad(st.error || en.error);
if (st.v && en.v && en.t <= st.t) return bad('"Show until" must be after "Show from".');
const is_active = String(b.is_active ?? '1') === '0' ? 0 : 1;

const bin = $input.first().binary || {};
const k = bin.image ? 'image' : Object.keys(bin)[0];
let file = null;
if (k) {
  const f = bin[k];
  const exts = { 'image/jpeg': 'jpg', 'image/jpg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };
  const mime = f.mimeType === 'image/jpg' ? 'image/jpeg' : f.mimeType;
  if (!exts[mime]) return bad('The picture must be a JPG or PNG image.');
  if (await byteSize(k, f) > 5 * 1024 * 1024) return bad('The picture must be under 5 MB.');
  let head = null;
  try { head = (await this.helpers.getBinaryDataBuffer(0, k)).subarray(0, 12); } catch (e) { head = Buffer.from(f.data || '', 'base64').subarray(0, 12); }
  const hex = head ? head.toString('hex') : '';
  if (!(hex.startsWith('ffd8ff') || hex.startsWith('89504e470d0a1a0a') || (hex.startsWith('52494646') && hex.slice(16, 24) === '57454250')))
    return bad('The picture must be a JPG or PNG image.');
  file = { field: k, mime, key: `home_banners/banner_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${exts[mime]}` };
}
const remove_image = kind === 'CARD' && String(b.remove_image ?? '') === '1';
return [{ json: { ...base, kind, title, subtitle: subtitle || null, badge: badge || null, theme, link_type, link_value,
  starts_at: st.v, ends_at: en.v, is_active, file, remove_image }, binary: bin }];""", [220, 0]))
n.append(iff("Request OK?", "={{ $json.ok }}", [440, 0]))
staff_gate(n, c, "Request OK?", 660)
c["Request OK?"]["main"] = [[{"node": "Load Staff", "type": "main", "index": 0}], [{"node": "Respond", "type": "main", "index": 0}]]
n.append(mysql("Load Current",
    "SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'kind', kind, 'title', title, 'image_key', image_key, 'is_active', is_active, 'sort_order', sort_order)) AS rows_json "
    "FROM home_banners",
    "", [1320, -200], always=True))
link(c, "Allowed?", "Load Current", 0); link(c, "Allowed?", "Respond", 1)
n.append(code("Plan", r"""
const r = $('Check Request').first().json;
const fail = (st, m) => [{ json: { ok: false, status: st, body: { success: false, message: m } } }];
let list = [];
try { list = typeof $json.rows_json === 'string' ? JSON.parse($json.rows_json) : ($json.rows_json || []); } catch (e) {}
// JSON_ARRAYAGG keeps no order, so sort here: home-screen position, then oldest first.
list.sort((x, y) => Number(x.sort_order) - Number(y.sort_order) || Number(x.id) - Number(y.id));
const cur = r.id ? list.find(x => x.id === r.id) : null;
if (r.id && !cur) return fail(404, 'This banner no longer exists. Refresh the page.');
const ok = (sql, params, message, upload = false) => [{ json: { ok: true, sql, params, message, upload } }];

if (r.action === 'DELETE') return ok('DELETE FROM home_banners WHERE id = $1', [r.id], `"${cur.title}" deleted.`);
if (r.action === 'TOGGLE') {
  const on = Number(cur.is_active) !== 1;
  return ok('UPDATE home_banners SET is_active = $1, updated_by = $2 WHERE id = $3', [on ? 1 : 0, r.sid, r.id], on ? `"${cur.title}" is on.` : `"${cur.title}" is off.`);
}
if (r.action === 'MOVE') {
  const i = list.findIndex(x => x.id === r.id), j = r.dir === 'UP' ? i - 1 : i + 1;
  if (j < 0 || j >= list.length) return ok('SELECT 1', [], 'Order saved.');
  [list[i], list[j]] = [list[j], list[i]];
  // Rewrite every position 1..n so the order stays clean. Ids are whole numbers read from the table.
  const ids = list.map(x => Number(x.id));
  if (!ids.every(Number.isInteger)) return fail(500, 'Could not save. Please try again.');
  const cases = ids.map((x, k) => `WHEN ${x} THEN ${k + 1}`).join(' ');
  return ok(`UPDATE home_banners SET sort_order = CASE id ${cases} END WHERE id IN (${ids.join(', ')})`, [], 'Order saved.');
}
// SAVE
if (r.kind === 'IMAGE' && !r.file && !(cur && cur.image_key)) return fail(422, 'Add the banner picture.');
const image_key = r.file ? r.file.key : (r.remove_image ? null : (cur ? cur.image_key : null));
const v = [r.kind, r.title, r.subtitle, r.badge, image_key, r.theme, r.link_type, r.link_value, r.starts_at, r.ends_at, r.is_active, r.sid];
if (cur) return ok('UPDATE home_banners SET kind = $1, title = $2, subtitle = $3, badge = $4, image_key = $5, image_url = NULL, theme = $6, cta_label = NULL, ' +
  'link_type = $7, link_value = $8, starts_at = $9, ends_at = $10, is_active = $11, updated_by = $12 WHERE id = $13', [...v, r.id], `"${r.title}" saved.`, !!r.file);
// New banners go first in the line.
return ok('UPDATE home_banners SET sort_order = sort_order + 1; INSERT INTO home_banners (kind, title, subtitle, badge, image_key, theme, link_type, link_value, ' +
  'starts_at, ends_at, is_active, updated_by, sort_order) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 1)', v, `"${r.title}" added. It shows first on the home screen.`, !!r.file);""", [1540, -200]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1760, -200]))
n.append(iff("New Picture?", "={{ $json.upload }}", [1980, -200]))
link(c, "Load Current", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "New Picture?", 0); link(c, "Plan OK?", "Respond", 1)
n.append(code("B2 Credentials", B2_AUTH, [2200, -400]))
n.append(http("Authorize B2", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [2400, -400]))
n.append(http("Upload URL", "GET", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_upload_url?bucketId=" + BUCKET_ID,
              [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}")], [2600, -400]))
n.append(code("Attach", r"""
const r = $('Check Request').first();
const f = r.json.file;
return [{ json: { uploadUrl: $json.uploadUrl, uploadToken: $json.authorizationToken, mime: f.mime,
  name: f.key.split('/').map(encodeURIComponent).join('/') }, binary: { file: r.binary[f.field] } }];""", [2800, -400]))
u = http("Upload", "POST", "={{ $json.uploadUrl }}",
         [("Authorization", "={{ $json.uploadToken }}"), ("X-Bz-File-Name", "={{ $json.name }}"),
          ("Content-Type", "={{ $json.mime }}"), ("X-Bz-Content-Sha1", "do_not_verify")],
         [3000, -400], binary_field="file", never_error=True)
u.update(retryOnFail=True, maxTries=3, waitBetweenTries=1000)
n.append(u)
n.append(iff("Uploaded?", "={{ $json.statusCode === 200 }}", [3200, -400]))
n.append(code("Upload Failed", "return [{ json: { status: 502, body: { success: false, message: 'Could not upload the picture. Please try again.' } } }];", [3400, -100]))
n.append(mysql("Save", "={{ $('Plan').first().json.sql }}", "={{ $('Plan').first().json.params }}", [3400, -300], continue_on_error=True))
n.append(code("Build Response", r"""
if ($json.error || /ER_|syntax/i.test(String($json.message || ''))) return [{ json: { status: 500, body: { success: false, message: 'Could not save. Please try again.' } } }];
return [{ json: { status: 200, body: { success: true, message: $('Plan').first().json.message } } }];""", [3620, -300]))
n.append(respond([3840, 0]))
link(c, "New Picture?", "B2 Credentials", 0); link(c, "New Picture?", "Save", 1)
link(c, "B2 Credentials", "Authorize B2"); link(c, "Authorize B2", "Upload URL"); link(c, "Upload URL", "Attach"); link(c, "Attach", "Upload")
link(c, "Upload", "Uploaded?"); link(c, "Uploaded?", "Save", 0); link(c, "Uploaded?", "Upload Failed", 1)
link(c, "Save", "Build Response"); link(c, "Build Response", "Respond"); link(c, "Upload Failed", "Respond")
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Request OK?")
out['staff_home_banner_save'] = workflow("StfHomeBs026mPxN", "MyPaltan v2 - Staff Home Banner Save", n, c)

# ───────────── 3. Views and taps from the app (batched) ─────────────
n, c = [], {}
n.append(webhook("v2/home/banners/track", "POST"))
n.append(code("Check Events", APP_AUTH + r"""
const auth = verifyToken($in.headers);
if (!auth.ok) return [{ json: { ok: false, status: 401, body: { success: false, message: auth.error } } }];
const ev = Array.isArray($in.body?.events) ? $in.body.events.slice(0, 50) : [];
const clean = ev.map(e => ({ bid: Number(e?.banner_id), v: Math.min(Math.max(Number(e?.views) || 0, 0), 5), t: Math.min(Math.max(Number(e?.taps) || 0, 0), 20) }))
  .filter(e => Number.isInteger(e.bid) && e.bid > 0 && (e.v > 0 || e.t > 0));
if (!clean.length) return [{ json: { ok: false, status: 200, body: { success: true, recorded: 0 } } }];
return [{ json: { ok: true, events: JSON.stringify(clean), count: clean.length } }];""", [220, 0]))
n.append(iff("Anything?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Record",
    "INSERT INTO home_banner_daily_stats (banner_id, day, views, taps) SELECT * FROM (SELECT j.bid, CURDATE() AS d, SUM(j.v) AS v, SUM(j.t) AS t "
    "FROM JSON_TABLE($1, '$[*]' COLUMNS (bid INT PATH '$.bid', v INT PATH '$.v', t INT PATH '$.t')) AS j JOIN home_banners b ON b.id = j.bid GROUP BY j.bid) AS x "
    "ON DUPLICATE KEY UPDATE views = views + x.v, taps = taps + x.t",
    "={{ [$json.events] }}", [660, -100], continue_on_error=True))
n.append(code("Build Response", "return [{ json: { status: 200, body: { success: true, recorded: $('Check Events').first().json.count } } }];", [880, -100]))
n.append(respond([1100, 0]))
link(c, "Webhook", "Check Events"); link(c, "Check Events", "Anything?")
link(c, "Anything?", "Record", 0); link(c, "Anything?", "Respond", 1)
link(c, "Record", "Build Response"); link(c, "Build Response", "Respond")
out['banner_track'] = workflow("HomeBnTrk026mPxO", "MyPaltan v2 - Home Banner Track", n, c)

# ───────────── 4. Home: banner kind + pictures from home_banners/ (patches the live export) ─────────────
if len(sys.argv) > 1:
    w = json.load(open(sys.argv[1]))
    w = w[0] if isinstance(w, list) else w
    nodes = {nd['name']: nd for nd in w['nodes']}
    q = nodes['Load Home']['parameters']['query']
    old_sel = "SELECT 'banner' AS _set, id, title,"
    assert q.count(old_sel) == 1
    nodes['Load Home']['parameters']['query'] = q.replace(old_sel, "SELECT 'banner' AS _set, id, kind, title,")
    if 'Banner Link' not in nodes:
        bl = json.loads(json.dumps(nodes['Assets Link']))
        bl.update(id=uid(), name='Banner Link', position=[nodes['Assets Link']['position'][0] + 200, nodes['Assets Link']['position'][1]])
        bl['parameters']['jsonBody'] = bl['parameters']['jsonBody'].replace("tournament_assets/", "home_banners/")
        assert 'home_banners/' in bl['parameters']['jsonBody']
        w['nodes'].append(bl)
        w['connections']['Assets Link'] = {"main": [[{"node": "Banner Link", "type": "main", "index": 0}]]}
        w['connections']['Banner Link'] = {"main": [[{"node": "Build Response", "type": "main", "index": 0}]]}
    js = nodes['Build Response']['parameters']['jsCode']
    old_tok = "const t = key && tokenOf(key.startsWith('tournament_assets/') ? 'Assets Link' : 'Logo Link');"
    new_tok = "const t = key && tokenOf(key.startsWith('tournament_assets/') ? 'Assets Link' : key.startsWith('home_banners/') ? 'Banner Link' : 'Logo Link');"
    old_b = "id: r.id, title: r.title,"
    for a, b_ in [(old_tok, new_tok), (old_b, "id: r.id, kind: r.kind || 'CARD', title: r.title,")]:
        assert js.count(a) == 1, a
        js = js.replace(a, b_)
    nodes['Build Response']['parameters']['jsCode'] = js
    w['active'] = False
    for k in ('shared', 'tags', 'activeVersion', 'activeVersionId', 'versionCounter', 'triggerCount'):
        w.pop(k, None)
    out['home'] = w

for k, w in out.items():
    json.dump(w, open(os.path.join(OUT, f'{k}.json'), 'w'), indent=2)
    print(k, w['id'], len(w['nodes']), 'nodes')
