"""Builds the n8n workflows for tournament web registration (mypaltan.com/register/<slug>).

  python3 build_web_registration.py   → writes ../workflows/v2/public_tournament_*.json and public_team_*.json

Coach registers a team and pays per player; parents add their child through the team's player link;
the coach approves children on a private manage link. Records are the same ones the app creates
(app_users, teams, team_members, tournament_entries, tournament_entry_players, notifications), so
organisers see web registrations in the app's Teams tab like any other.
"""
import json, os, uuid

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'workflows', 'v2')
MYSQL = {"mySql": {"id": "cJO42PjVTTGgCHL1", "name": "MyPaltanDB"}}
BUCKET_ID = "57d8ff72a9534e199bf30918"
BUCKET_NAME = "mypaltan-profile-photos"
ORIGINS = "https://mypaltan.com,https://www.mypaltan.com,http://localhost:5180"
DEFAULT_TEAM_LOGO = "team_assets/default/team_logo_mypaltan.png"
SIZE_HELPER = open(os.path.join(HERE, '_size_helper.js')).read()
SHA256 = open(os.path.join(HERE, '_sha256.js')).read() + \
    "const sha256hex = s => sha256bytes(s).map(b => b.toString(16).padStart(2, '0')).join('');\n"
RESP_OUT = "={{ JSON.stringify($json.body) }}"
RESP_CODE = "={{ $json.status }}"
B2_AUTH = "return $input.all().map(i => ({ json: { ...i.json, basicAuth: 'Basic ' + Buffer.from(`${$env.B2_KEY_ID}:${$env.B2_APPLICATION_KEY}`).toString('base64') }, binary: i.binary }));"


def uid():
    return str(uuid.uuid4())


def node(name, type_, version, pos, params, **extra):
    n = {"parameters": params, "name": name, "type": type_, "typeVersion": version, "position": list(pos), "id": uid()}
    n.update(extra)
    return n


def webhook(path, method):
    return node("Webhook", "n8n-nodes-base.webhook", 2.1, (0, 0),
                {"httpMethod": method, "path": path, "responseMode": "responseNode", "options": {"allowedOrigins": ORIGINS}},
                webhookId=uid())


def code(name, js, pos):
    js = js.replace('$json', '$in')  # n8n code nodes (run once for all items) have no $json
    if '$in' in js:
        js = 'const $in = $input.first().json;\n' + js
    return node(name, "n8n-nodes-base.code", 2, pos, {"jsCode": js})


def mysql(name, query, values_expr, pos, always=False, continue_on_error=False):
    extra = {"credentials": MYSQL}
    if always:
        extra["alwaysOutputData"] = True
    if continue_on_error:
        extra["onError"] = "continueRegularOutput"
    return node(name, "n8n-nodes-base.mySql", 2.2, pos,
                {"operation": "executeQuery", "query": query, "options": {"queryReplacement": values_expr}}, **extra)


def iff(name, expr, pos):
    return node(name, "n8n-nodes-base.if", 2.2, pos, {"conditions": {
        "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "loose", "version": 2},
        "conditions": [{"id": uid(), "leftValue": expr, "rightValue": "", "operator": {"type": "boolean", "operation": "true", "singleValue": True}}],
        "combinator": "and"}, "options": {}})


def respond(pos):
    return node("Respond", "n8n-nodes-base.respondToWebhook", 1.5, pos,
                {"respondWith": "json", "responseBody": RESP_OUT, "options": {"responseCode": RESP_CODE}})


def http(name, method, url, headers, pos, json_body=None, binary_field=None, never_error=False):
    p = {"method": method, "url": url, "sendHeaders": True,
         "headerParameters": {"parameters": [{"name": k, "value": v} for k, v in headers]}, "options": {}}
    if json_body is not None:
        p.update({"sendBody": True, "specifyBody": "json", "jsonBody": json_body})
    if binary_field is not None:
        p.update({"sendBody": True, "contentType": "binaryData", "inputDataFieldName": binary_field})
    if never_error:
        p["options"] = {"response": {"response": {"fullResponse": True, "neverError": True}}}
    return node(name, "n8n-nodes-base.httpRequest", 4.2, pos, p)


def link(c, a, b, out=0):
    c.setdefault(a, {"main": []})
    while len(c[a]["main"]) <= out:
        c[a]["main"].append([])
    c[a]["main"][out].append({"node": b, "type": "main", "index": 0})


def workflow(wid, name, nodes, conns):
    return {"id": wid, "name": name, "active": False, "nodes": nodes, "connections": conns,
            "settings": {"executionOrder": "v1"}, "pinData": {}}


# ── Shared JS ──
def rate(limit):
    """Per-network limit kept in the workflow's static data; counts requests that pass the checks."""
    return r"""
const h = $in.headers || {};
const ip = String(h['x-real-ip'] || String(h['x-forwarded-for'] || '').split(',')[0] || 'unknown').trim();
const store = $getWorkflowStaticData('global');
const now = Date.now();
store.hits = Object.fromEntries(Object.entries(store.hits || {}).map(([k, v]) => [k, v.filter(t => now - t < 3600e3)]).filter(([, v]) => v.length));
const mine = store.hits[ip] || [];
if (mine.length >= """ + str(limit) + r""") return [{ json: { ok: false, status: 429, body: { success: false, message: 'Too many attempts from this network. Please try again in an hour.' } } }];
const count = () => { store.hits[ip] = [...mine, now]; };
"""


COMMON = r"""
const b = $in.body || {};
const bad = (m, status = 422) => [{ json: { ok: false, status, body: { success: false, message: m } } }];
const str = v => String(v ?? '').trim();
const rand = (n, chars) => {
  const out = [];
  const g = globalThis.crypto && globalThis.crypto.getRandomValues ? globalThis.crypto.getRandomValues(new Uint32Array(n)) : null;
  for (let i = 0; i < n; i++) out.push(chars[(g ? g[i] : Math.floor(Math.random() * 4294967296)) % chars.length]);
  return out.join('');
};
const EXTS = { 'image/jpeg': 'jpg', 'image/jpg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic' };
// A real JPG, PNG, WebP or HEIC, under 8 MB. Returns { mime, ext } or an error message.
const checkImage = async (bin, k, label) => {
  const f = bin[k];
  const mime = f.mimeType === 'image/jpg' ? 'image/jpeg' : f.mimeType;
  if (!EXTS[mime]) return { error: `The ${label} must be a photo (JPG or PNG).` };
  if (await byteSize(k, f) > 8 * 1024 * 1024) return { error: `The ${label} must be under 8 MB.` };
  let head = null;
  try { head = (await this.helpers.getBinaryDataBuffer(0, k)).subarray(0, 12); } catch (e) { head = Buffer.from(f.data || '', 'base64').subarray(0, 12); }
  const hex = head ? head.toString('hex') : '';
  const ok = hex.startsWith('ffd8ff') || hex.startsWith('89504e470d0a1a0a') ||
    (hex.startsWith('52494646') && hex.slice(16, 24) === '57454250') || hex.slice(8, 16) === '66747970';
  return ok ? { mime, ext: EXTS[mime] } : { error: `The ${label} must be a photo (JPG or PNG).` };
};
const fileKey = (dir, phone, kind, ext) => `${dir}/${phone}/${kind}_${Date.now()}_${rand(6, 'abcdefghijklmnopqrstuvwxyz0123456789')}.${ext}`;
const SLUG = /^[a-z0-9-]{2,40}$/;
"""


def upload_chain(n, c, after, x, y, then, failed):
    """Uploads every item from the "Files" node to B2 (one upload URL per file), then continues to `then`."""
    n.append(code("Files", r"""
const r = $('Check Request').first();
return (r.json.files || []).map(f => ({ json: f, binary: { file: r.binary[f.field] } }));""", [x, y]))
    n.append(code("B2 Credentials", B2_AUTH, [x + 200, y]))
    a = http("Authorize B2", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [x + 400, y])
    a["executeOnce"] = True
    n.append(a)
    # Authorize B2 runs once, so hand every file on again: one upload URL per file.
    n.append(code("Each File", "return $('Files').all().map(i => ({ json: i.json }));", [x + 500, y + 150]))
    n.append(http("Upload URL", "GET", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_upload_url?bucketId=" + BUCKET_ID,
                  [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}")], [x + 600, y]))
    # The upload-URL node ran once per file, so its items line up with the Files items by position.
    n.append(code("Attach", r"""
const files = $('Files').all();
return $input.all().map((u, i) => ({ json: { uploadUrl: u.json.uploadUrl, uploadToken: u.json.authorizationToken, mime: files[i].json.mime,
  name: files[i].json.key.split('/').map(encodeURIComponent).join('/') }, binary: { file: files[i].binary.file } }));""", [x + 800, y]))
    u = http("Upload", "POST", "={{ $json.uploadUrl }}",
             [("Authorization", "={{ $json.uploadToken }}"), ("X-Bz-File-Name", "={{ $json.name }}"),
              ("Content-Type", "={{ $json.mime }}"), ("X-Bz-Content-Sha1", "do_not_verify")],
             [x + 1000, y], binary_field="file", never_error=True)
    u.update(retryOnFail=True, maxTries=3, waitBetweenTries=1000)
    n.append(u)
    n.append(code("All Uploaded", "return [{ json: { ok: $input.all().every(i => i.json.statusCode === 200) } }];", [x + 1200, y]))
    n.append(iff("Uploaded?", "={{ $json.ok }}", [x + 1400, y]))
    link(c, after, "Files"); link(c, "Files", "B2 Credentials"); link(c, "B2 Credentials", "Authorize B2")
    link(c, "Authorize B2", "Each File"); link(c, "Each File", "Upload URL")
    link(c, "Upload URL", "Attach"); link(c, "Attach", "Upload"); link(c, "Upload", "All Uploaded")
    link(c, "All Uploaded", "Uploaded?"); link(c, "Uploaded?", then, 0); link(c, "Uploaded?", failed, 1)


def save_and_respond(n, c, x, ok_message_js, dup_message='Please try again.'):
    n.append(mysql("Save", "={{ $('Plan').first().json.sql }}", "={{ $('Plan').first().json.params }}", [x, -300], continue_on_error=True))
    n.append(code("Build Response", r"""
const msg = String($json.message || $json.error?.message || '');
if (msg.includes('Duplicate')) return [{ json: { status: 409, body: { success: false, message: """ + json.dumps(dup_message) + r""" } } }];
if ($json.error || /ER_|syntax/i.test(msg)) return [{ json: { status: 500, body: { success: false, message: 'Could not save. Please try again.' } } }];
const p = $('Plan').first().json;
""" + ok_message_js, [x + 220, -300]))
    n.append(code("Upload Failed", "return [{ json: { status: 502, body: { success: false, message: 'Could not upload your photo. Please check your internet and try again.' } } }];", [x, 100]))
    link(c, "Save", "Build Response"); link(c, "Build Response", "Respond"); link(c, "Upload Failed", "Respond")


out = {}

# ───────────── 1. Form details: tournament, age groups, slots, payment QR; with ?team=, the team for the player link ─────────────
n, c = [], {}
n.append(webhook("v2/public/tournament-form", "GET"))
n.append(code("Check Request", rate(600) + r"""
const q = $in.query || {};
const slug = String(q.slug ?? '').toLowerCase(), team = String(q.team ?? '').toUpperCase();
if (!/^[a-z0-9-]{2,40}$/.test(slug)) return [{ json: { ok: false, status: 404, body: { success: false, message: 'This registration link is not valid.' } } }];
if (team && !/^[A-Z0-9]{6}$/.test(team)) return [{ json: { ok: false, status: 404, body: { success: false, message: 'This team link is not valid.' } } }];
count();
return [{ json: { ok: true, slug, team } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load",
    "SELECT l.fee_per_player, t.id AS tid, t.code, t.name, t.status, DATE_FORMAT(t.start_date, '%Y-%m-%d') AS start_date, "
    "DATE_FORMAT(t.registration_deadline, '%Y-%m-%d %H:%i') AS deadline, (t.registration_deadline < NOW()) AS closed, (t.start_date <= CURDATE()) AS started, "
    "t.area, t.city, (SELECT JSON_ARRAYAGG(g.name) FROM tournament_grounds g WHERE g.tournament_id = t.id) AS grounds, "
    "p.upi_id, p.upi_name, p.qr_key, p.note AS pay_note, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('id', d.id, 'name', d.name, 'min_age', d.min_age, 'max_age', d.max_age, 'squad_min', d.squad_min, 'squad_max', d.squad_max, "
    "'max_teams', d.max_teams, 'approved', (SELECT COUNT(*) FROM tournament_entries e WHERE e.division_id = d.id AND e.status = 'APPROVED'), "
    "'waiting', (SELECT COUNT(*) FROM tournament_entries e WHERE e.division_id = d.id AND e.status IN ('PENDING', 'WAITLISTED')))) "
    "FROM tournament_divisions d WHERE d.tournament_id = t.id) AS divisions, "
    "tm.code AS team_code, tm.name AS team_name, e.status AS entry_status, e.division_id AS team_division, e.paid_players, "
    "(SELECT COUNT(*) FROM tournament_entry_players ep WHERE ep.entry_id = e.id) AS squad_count "
    "FROM tournament_web_links l JOIN tournaments t ON t.id = l.tournament_id LEFT JOIN tournament_payment_details p ON p.tournament_id = t.id "
    "LEFT JOIN teams tm ON tm.code = $2 LEFT JOIN tournament_entries e ON e.tournament_id = t.id AND e.team_id = tm.id "
    "WHERE l.slug = $1",
    "={{ [$json.slug, $json.team || '-'] }}", [660, -100], always=True))
n.append(code("Shape", r"""
const r = $json, q = $('Check Request').first().json;
if (!r.tid) return [{ json: { done: true, status: 404, body: { success: false, message: 'This registration link is not valid.' } } }];
const parse = v => { if (v == null) return null; if (typeof v === 'object') return v; try { return JSON.parse(v); } catch { return null; } };
const divisions = (parse(r.divisions) || []).sort((a, b) => a.id - b.id);
const team = q.team && r.team_code && r.entry_status ? (d => ({ code: r.team_code, name: r.team_name, status: r.entry_status,
  division_id: r.team_division, division: d ? d.name : null, min_age: d ? d.min_age : null, max_age: d ? d.max_age : null,
  squad_max: d ? d.squad_max : null, paid_players: r.paid_players, squad_count: Number(r.squad_count) }))(divisions.find(d => d.id === r.team_division)) : null;
const body = { success: true,
  tournament: { code: r.code, name: r.name, start_date: r.start_date, deadline: r.deadline, area: r.area, city: r.city, grounds: parse(r.grounds) || [],
    open: r.status === 'REGISTRATION_OPEN' && Number(r.closed) !== 1, started: Number(r.started) === 1 },
  fee_per_player: Number(r.fee_per_player), divisions, team,
  payment: r.upi_id ? { upi_id: r.upi_id, upi_name: r.upi_name, note: r.pay_note || null, qr_url: null } : null };
if (q.team && !team) body.team_error = 'This team link is not valid.';
// The QR link is signed once and reused for about 20 hours.
const cached = ($getWorkflowStaticData('global').qr || {})[r.qr_key];
if (!r.qr_key || !body.payment) return [{ json: { done: true, status: 200, body } }];
if (cached && cached.exp > Date.now()) { body.payment.qr_url = cached.url; return [{ json: { done: true, status: 200, body } }]; }
return [{ json: { done: false, body, qr_key: r.qr_key } }];""", [880, -100]))
n.append(iff("Done?", "={{ $json.done }}", [1100, -100]))
n.append(code("B2 Credentials", B2_AUTH, [1320, -200]))
n.append(http("Authorize B2", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [1520, -200]))
n.append(http("QR Link", "POST", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_download_authorization",
              [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}"), ("Content-Type", "application/json")], [1720, -200],
              json_body="={{ JSON.stringify({ bucketId: '" + BUCKET_ID + "', fileNamePrefix: $('Shape').first().json.qr_key, validDurationInSeconds: 86400 }) }}"))
n.append(code("Sign", r"""
const s = $('Shape').first().json, b2 = $('Authorize B2').first().json;
const url = `${b2.apiInfo.storageApi.downloadUrl}/file/""" + BUCKET_NAME + r"""/${s.qr_key.split('/').map(encodeURIComponent).join('/')}?Authorization=${$json.authorizationToken}`;
const store = $getWorkflowStaticData('global');
store.qr = { ...(store.qr || {}), [s.qr_key]: { url, exp: Date.now() + 20 * 3600e3 } };
return [{ json: { status: 200, body: { ...s.body, payment: { ...s.body.payment, qr_url: url } } } }];""", [1920, -200]))
n.append(respond([2140, 0]))
next(x for x in n if x["name"] == "QR Link")["onError"] = "continueRegularOutput"
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Shape"); link(c, "Shape", "Done?")
link(c, "Done?", "Respond", 0); link(c, "Done?", "B2 Credentials", 1)
link(c, "B2 Credentials", "Authorize B2"); link(c, "Authorize B2", "QR Link"); link(c, "QR Link", "Sign"); link(c, "Sign", "Respond")
out['public_tournament_form'] = workflow("PubTrnFrm026mPxE", "MyPaltan v2 - Public Tournament Form", n, c)

# ───────────── 2. Coach registers a team and pays for N players ─────────────
n, c = [], {}
n.append(webhook("v2/public/tournament-register", "POST"))
n.append(code("Check Request", SIZE_HELPER + SHA256 + rate(20) + COMMON + r"""
if (b.website) return bad('Please try again.');            // hidden field only bots fill in
const slug = str(b.slug).toLowerCase();
if (!SLUG.test(slug)) return bad('This registration link is not valid.', 404);
const coach = str(b.coach_name).replace(/\s+/g, ' ');
if (coach.length < 2 || coach.length > 50 || !/^[\p{L}][\p{L} .'-]*$/u.test(coach)) return bad("Enter the coach's full name.");
const phone = str(b.phone).replace(/\D/g, '').slice(-10);
if (!/^[6-9]\d{9}$/.test(phone)) return bad('Enter a valid 10-digit mobile number.');
const team = str(b.team_name).replace(/\s+/g, ' ');
if (team.length < 2 || team.length > 40 || !/^[\p{L}\p{N}][\p{L}\p{N} .'&-]*$/u.test(team)) return bad('Team name must be 2-40 letters or numbers.');
const area = str(b.area).replace(/\s+/g, ' ').slice(0, 100) || null;
const division = Number(b.division_id);
if (!(Number.isInteger(division) && division > 0)) return bad('Choose the age group.');
// Every team pays for a full squad of its age group (worked out from the division below).
const utr = str(b.utr) === '' ? null : str(b.utr).replace(/\s/g, '').toUpperCase();
if (utr !== null && !/^[A-Z0-9]{6,30}$/.test(utr)) return bad('Enter the UTR or transaction number exactly as shown in your UPI app.');
if (b.agree_rules !== '1' || b.agree_refund !== '1' || b.agree_parents !== '1') return bad('Please tick all three boxes to continue.');
const bin = $input.first().binary || {};
const files = [];
if (!bin.logo) return bad('Add your team logo.');
{ const r = await checkImage(bin, 'logo', 'team logo'); if (r.error) return bad(r.error); files.push({ field: 'logo', mime: r.mime, key: fileKey('team_assets', phone, 'team_logo', r.ext) }); }
if (bin.payment) { const r = await checkImage(bin, 'payment', 'payment screenshot'); if (r.error) return bad(r.error); files.push({ field: 'payment', mime: r.mime, key: fileKey('payment_proof', phone, 'payment_proof', r.ext) }); }
if (!utr && !bin.payment) return bad('Add the UTR number or a screenshot of your payment.');
// Short name for scorecards: initials of the words, or the first letters of a one-word name.
const words = team.toUpperCase().replace(/[^A-Z0-9 ]/g, '').split(' ').filter(Boolean);
const short = (words.length > 1 ? words.map(w => w[0]).join('') : (words[0] || 'TEAM')).slice(0, 4).padEnd(2, 'X');
const key = rand(32, 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789');
count();
return [{ json: { ok: true, slug, coach, phone, team, short, area, division, utr, files, key, key_hash: sha256hex(key),
  code: rand(6, 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789') } , binary: bin }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load",
    "SELECT l.fee_per_player, t.id AS tid, t.code, t.name AS tname, t.status, (t.registration_deadline < NOW()) AS closed, t.organizer_user_id, "
    "d.id AS did, d.name AS dname, d.squad_min, d.squad_max, d.max_teams, "
    "(SELECT COUNT(*) FROM tournament_entries e WHERE e.division_id = d.id AND e.status = 'APPROVED') AS approved, "
    "u.id AS uid, (SELECT COUNT(*) FROM tournament_entries e JOIN teams x ON x.id = e.team_id WHERE e.tournament_id = t.id "
    "AND LOWER(x.name) = LOWER($4) AND e.status NOT IN ('REJECTED', 'WITHDRAWN')) AS same_name, "
    "(SELECT COUNT(*) FROM teams x WHERE x.code = $5) AS code_taken "
    "FROM tournament_web_links l JOIN tournaments t ON t.id = l.tournament_id "
    "LEFT JOIN tournament_divisions d ON d.id = $2 AND d.tournament_id = t.id LEFT JOIN app_users u ON u.phone = $3 WHERE l.slug = $1",
    "={{ [$json.slug, $json.division, $json.phone, $json.team, $json.code] }}", [660, -100], always=True))
n.append(code("Plan", r"""
const s = $json, r = $('Check Request').first().json;
const fail = (m, status = 422) => [{ json: { ok: false, status, body: { success: false, message: m } } }];
if (!s.tid) return fail('This registration link is not valid.', 404);
if (s.status !== 'REGISTRATION_OPEN' || Number(s.closed) === 1) return fail('Registration for this tournament is closed.', 409);
if (!s.did) return fail('Choose the age group.');
const players = Number(s.squad_max);  // a full squad
if (Number(s.same_name) > 0) return fail(`A team called ${r.team} is already registered. Please use a different name.`, 409);
if (Number(s.code_taken) > 0) return fail('Please tap Register again.', 409);
const perPlayer = Number(s.fee_per_player || 0), fee = perPlayer * players;
const status = Number(s.approved) >= Number(s.max_teams) ? 'WAITLISTED' : 'PENDING';
const proof = (r.files.find(f => f.field === 'payment') || {}).key || null;
const logo = (r.files.find(f => f.field === 'logo') || {}).key || '""" + DEFAULT_TEAM_LOGO + r"""';
const p = [], st = [];
const add = v => { p.push(v); return '$' + p.length; };
if (s.uid) st.push(`SET @u = ${add(s.uid)}`);
else { st.push(`INSERT INTO app_users (phone, name) VALUES (${add(r.phone)}, ${add(r.coach)})`); st.push('SET @u = LAST_INSERT_ID()'); }
st.push(`INSERT INTO teams (code, sport, name, short_name, logo_key, area, city, captain_user_id) VALUES (${add(r.code)}, 'FOOTBALL', ${add(r.team)}, ` +
  `${add(r.short)}, ${add(logo)}, ${add(r.area)}, 'Mumbai', @u)`);
st.push('SET @t = LAST_INSERT_ID()');
st.push("INSERT INTO team_members (team_id, user_id, role, added_by) VALUES (@t, @u, 'COACH', @u)");
st.push(`INSERT INTO tournament_entries (tournament_id, division_id, team_id, registered_by, status, payment_method, amount, paid_players, manage_key_hash, utr, proof_key, payment_claimed_at) ` +
  `VALUES (${add(s.tid)}, ${add(s.did)}, @t, @u, ${add(status)}, 'UPI', ${add(fee)}, ${add(players)}, ${add(r.key_hash)}, ${add(r.utr)}, ${add(proof)}, NOW())`);
st.push('SET @e = LAST_INSERT_ID()');
st.push(`INSERT INTO entry_payments (entry_id, players, amount, utr, proof_key) VALUES (@e, ${add(players)}, ${add(fee)}, ${add(r.utr)}, ${add(proof)})`);
const inr = v => '₹' + Number(v).toLocaleString('en-IN');
st.push(`INSERT INTO notifications (user_id, type, title, body, data) VALUES (${add(s.organizer_user_id)}, 'ENTRY', ${add(`${r.team} registered for ${s.dname}`)}, ` +
  `${add(`Registered on the website by ${r.coach} for a full squad of ${players} players. Paid ${inr(fee)} by UPI${r.utr ? ` (UTR ${r.utr})` : ''}. Players join after the coach approves them. Review it in the Teams tab.`)}, ` +
  `JSON_OBJECT('tournament_code', ${add(s.code)}))`);
st.push('SELECT @e AS entry_id');
return [{ json: { ok: true, sql: st.join('; '), params: p, has_files: r.files.length > 0,
  result: { team_code: r.code, team: r.team, manage_key: r.key, division: s.dname, players, amount: fee, status } } }];""", [880, -100]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1100, -100]))
n.append(iff("Has Files?", "={{ $json.has_files }}", [1320, -200]))
upload_chain(n, c, "Has Files?", 1540, -400, "Save", "Upload Failed")
save_and_respond(n, c, 3300, r"""
const m = p.result.status === 'WAITLISTED'
  ? `${p.result.division} is full, so ${p.result.team} is on the waitlist. The organiser will tell you if a place opens up.`
  : `${p.result.team} is registered for ${p.result.division}. The organiser confirms the team after checking your payment.`;
return [{ json: { status: 200, body: { success: true, message: m, ...p.result } } }];""", 'Please tap Register again.')
n.append(respond([3800, 0]))
c["Has Files?"]["main"][0] = [{"node": "Files", "type": "main", "index": 0}]
link(c, "Has Files?", "Save", 1)
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Has Files?", 0); link(c, "Plan OK?", "Respond", 1)
out['public_tournament_register'] = workflow("PubTrnReg026mPxF", "MyPaltan v2 - Public Tournament Register", n, c)

# ───────────── 3. Parent adds their child to a team (waits for the coach) ─────────────
n, c = [], {}
n.append(webhook("v2/public/team-join", "POST"))
n.append(code("Check Request", SIZE_HELPER + rate(30) + COMMON + r"""
if (b.website) return bad('Please try again.');
const slug = str(b.slug).toLowerCase(), team = str(b.team).toUpperCase();
if (!SLUG.test(slug) || !/^[A-Z0-9]{6}$/.test(team)) return bad('This team link is not valid.', 404);
// Same checks as a coach adding a player in the app.
const name = str(b.name).replace(/\s+/g, ' ');
if (name.length < 2 || name.length > 50 || !/^[\p{L}][\p{L} .'-]*$/u.test(name)) return bad("Enter the player's full name.");
const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(str(b.birthdate));
const bd = m ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3])) : null;
if (!bd || bd.getUTCMonth() !== +m[2] - 1) return bad('Enter the date of birth.');
const today = new Date();
let age = today.getUTCFullYear() - bd.getUTCFullYear();
if (today.getUTCMonth() < bd.getUTCMonth() || (today.getUTCMonth() === bd.getUTCMonth() && today.getUTCDate() < bd.getUTCDate())) age--;
if (age < 3) return bad('Players must be at least 3 years old.');
if (age >= 13) return bad('Players aged 13 or older join with their own MyPaltan account. Ask the coach for help.');
const gender = str(b.gender || 'UNDISCLOSED').toUpperCase();
if (!['MALE', 'FEMALE', 'UNDISCLOSED'].includes(gender)) return bad('Choose a gender option.');
const jersey = str(b.jersey_number) === '' ? null : Number(b.jersey_number);
if (jersey !== null && !(Number.isInteger(jersey) && jersey >= 0 && jersey <= 99)) return bad('Jersey number must be 0 to 99.');
const parent = str(b.parent_phone).replace(/\D/g, '').slice(-10);
if (!/^[6-9]\d{9}$/.test(parent)) return bad("Enter the parent's 10-digit mobile number.");
if (b.agree_parent !== '1') return bad("Please confirm you are the player's parent or guardian.");
const bin = $input.first().binary || {};
const files = [];
if (bin.photo) { const r = await checkImage(bin, 'photo', 'photo'); if (r.error) return bad(r.error); files.push({ field: 'photo', mime: r.mime, key: fileKey('team_assets', parent, 'player_photo', r.ext) }); }
count();
return [{ json: { ok: true, slug, team, name, birthdate: m[0], gender, jersey, parent, files }, binary: bin }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load",
    "SELECT t.id AS tid, DATE_FORMAT(t.start_date, '%e %b') AS day, (t.start_date <= CURDATE()) AS started, tm.id AS team_id, tm.name AS team_name, "
    "e.id AS eid, e.status AS estatus, d.name AS dname, d.min_age, d.max_age, TIMESTAMPDIFF(YEAR, $4, t.start_date) AS age_on_day, "
    "(SELECT COUNT(*) FROM team_members x WHERE x.team_id = tm.id AND x.status IN ('ACTIVE', 'PENDING') AND LOWER(x.guest_name) = LOWER($3) AND x.guest_birthdate = $4) AS dup, "
    "(SELECT COUNT(*) FROM team_members x WHERE x.team_id = tm.id AND x.status = 'PENDING') AS pending "
    "FROM tournament_web_links l JOIN tournaments t ON t.id = l.tournament_id JOIN teams tm ON tm.code = $2 "
    "JOIN tournament_entries e ON e.tournament_id = t.id AND e.team_id = tm.id LEFT JOIN tournament_divisions d ON d.id = e.division_id WHERE l.slug = $1",
    "={{ [$json.slug, $json.team, $json.name, $json.birthdate] }}", [660, -100], always=True))
n.append(code("Plan", r"""
const s = $json, r = $('Check Request').first().json;
const fail = (m, status = 422) => [{ json: { ok: false, status, body: { success: false, message: m } } }];
if (!s.tid) return fail('This team link is not valid. Ask your coach for the right link.', 404);
if (['REJECTED', 'WITHDRAWN'].includes(s.estatus)) return fail(`${s.team_name} is no longer registered for this tournament.`, 409);
if (Number(s.started) === 1) return fail('Squads are closed for this tournament.', 409);
const first = r.name.split(' ')[0], age = Number(s.age_on_day);
if (s.max_age != null && age > s.max_age) return fail(`${first} will be ${age} on ${s.day}, too old for ${s.dname}.`);
if (s.min_age != null && age < s.min_age) return fail(`${first} will be ${age} on ${s.day}, too young for ${s.dname}.`);
if (Number(s.dup) > 0) return fail(`${r.name} is already added to ${s.team_name}.`, 409);
if (Number(s.pending) >= 40) return fail('Too many players are waiting for the coach. Ask the coach to approve them first.', 409);
const photo = (r.files[0] || {}).key || null;
return [{ json: { ok: true, has_files: r.files.length > 0,
  sql: "INSERT INTO team_members (team_id, user_id, parent_phone, guest_name, guest_birthdate, guest_gender, guest_photo_key, role, jersey_number, added_by, status) " +
    "VALUES ($1, NULL, $2, $3, $4, $5, $6, 'PLAYER', $7, NULL, 'PENDING')",
  params: [s.team_id, r.parent, r.name, r.birthdate, r.gender, photo, r.jersey],
  result: { name: r.name, team: s.team_name, division: s.dname } } }];""", [880, -100]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1100, -100]))
n.append(iff("Has Files?", "={{ $json.has_files }}", [1320, -200]))
upload_chain(n, c, "Has Files?", 1540, -400, "Save", "Upload Failed")
save_and_respond(n, c, 3300, r"""
return [{ json: { status: 200, body: { success: true, message: `Thanks! ${p.result.name} is added to ${p.result.team}. The coach will confirm the squad.`, ...p.result } } }];""")
n.append(respond([3800, 0]))
c["Has Files?"]["main"][0] = [{"node": "Files", "type": "main", "index": 0}]
link(c, "Has Files?", "Save", 1)
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Has Files?", 0); link(c, "Plan OK?", "Respond", 1)
out['public_team_join'] = workflow("PubTeamJn026mPxG", "MyPaltan v2 - Public Team Join", n, c)

# ───────────── 4. Coach's private manage link: see players, approve / reject / remove, pay for extra players ─────────────
n, c = [], {}
n.append(webhook("v2/public/team-manage", "POST"))
n.append(code("Check Request", SIZE_HELPER + SHA256 + rate(300) + COMMON + r"""
const key = str(b.key);
if (!/^[A-Za-z0-9]{32}$/.test(key)) return bad('This link is not valid. Use the link you got after registering.', 404);
const action = str(b.action || 'LOAD').toUpperCase();
if (!['LOAD', 'APPROVE', 'REJECT', 'REMOVE', 'PAY_EXTRA'].includes(action)) return bad('Invalid request.');
const member = Number(b.member_id || 0);
if (['APPROVE', 'REJECT', 'REMOVE'].includes(action) && !(Number.isInteger(member) && member > 0)) return bad('Invalid request.');
let extra = 0, utr = null;
const files = [];
if (action === 'PAY_EXTRA') {
  extra = Number(b.players);
  if (!(Number.isInteger(extra) && extra > 0 && extra <= 20)) return bad('Choose how many extra players you are paying for.');
  utr = str(b.utr) === '' ? null : str(b.utr).replace(/\s/g, '').toUpperCase();
  if (utr !== null && !/^[A-Z0-9]{6,30}$/.test(utr)) return bad('Enter the UTR or transaction number exactly as shown in your UPI app.');
  const bin = $input.first().binary || {};
  if (bin.payment) { const r = await checkImage(bin, 'payment', 'payment screenshot'); if (r.error) return bad(r.error); files.push({ field: 'payment', mime: r.mime, key: null, ext: r.ext }); }
  if (!utr && !bin.payment) return bad('Add the UTR number or a screenshot of your payment.');
}
count();
return [{ json: { ok: true, hash: sha256hex(key), action, member, extra, utr, files }, binary: $input.first().binary || {} }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load",
    "SELECT e.id AS eid, e.status AS estatus, e.reject_reason, e.paid_players, e.amount, t.id AS tid, t.code AS tcode, t.name AS tname, "
    "DATE_FORMAT(t.start_date, '%Y-%m-%d') AS start_date, DATE_FORMAT(t.start_date, '%e %b') AS day, (t.start_date <= CURDATE()) AS started, t.organizer_user_id, "
    "(SELECT l.slug FROM tournament_web_links l WHERE l.tournament_id = t.id LIMIT 1) AS slug, "
    "(SELECT l.fee_per_player FROM tournament_web_links l WHERE l.tournament_id = t.id LIMIT 1) AS fee_per_player, "
    "tm.id AS team_id, tm.code AS team_code, tm.name AS team_name, u.phone AS coach_phone, d.name AS dname, d.min_age, d.max_age, d.squad_min, d.squad_max, "
    "(SELECT COUNT(*) FROM tournament_entry_players ep WHERE ep.entry_id = e.id) AS squad_count, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('id', x.id, 'name', COALESCE(au.name, x.guest_name), 'birthdate', DATE_FORMAT(COALESCE(au.birthdate, x.guest_birthdate), '%Y-%m-%d'), "
    "'age', TIMESTAMPDIFF(YEAR, COALESCE(au.birthdate, x.guest_birthdate), t.start_date), 'gender', COALESCE(au.gender, x.guest_gender), "
    "'jersey_number', COALESCE(x.jersey_number, au.jersey_number), 'parent_phone', x.parent_phone, 'photo_key', COALESCE(x.guest_photo_key, au.photo_key), "
    "'status', x.status, 'in_squad', (SELECT COUNT(*) FROM tournament_entry_players ep WHERE ep.entry_id = e.id AND ep.team_member_id = x.id), "
    "'joined', DATE_FORMAT(CONVERT_TZ(x.joined_at, '+00:00', '+05:30'), '%e %b, %l:%i %p'))) "
    "FROM team_members x LEFT JOIN app_users au ON au.id = x.user_id WHERE x.team_id = tm.id AND x.status IN ('ACTIVE', 'PENDING') AND x.role <> 'COACH') AS members, "
    "(SELECT JSON_ARRAYAGG(JSON_OBJECT('players', pp.players, 'amount', pp.amount, 'utr', pp.utr, "
    "'at', DATE_FORMAT(CONVERT_TZ(pp.created_at, '+00:00', '+05:30'), '%e %b, %l:%i %p'))) FROM entry_payments pp WHERE pp.entry_id = e.id) AS payments, "
    "g.id AS tgt_id, g.status AS tgt_status, g.role AS tgt_role, g.user_id AS tgt_user, COALESCE(g.guest_name, '') AS tgt_name, g.jersey_number AS tgt_jersey, "
    "TIMESTAMPDIFF(YEAR, g.guest_birthdate, t.start_date) AS tgt_age, "
    "(SELECT COUNT(*) FROM tournament_entry_players ep WHERE ep.entry_id = e.id AND ep.team_member_id = g.id) AS tgt_in_squad "
    "FROM tournament_entries e JOIN tournaments t ON t.id = e.tournament_id JOIN teams tm ON tm.id = e.team_id JOIN app_users u ON u.id = tm.captain_user_id "
    "LEFT JOIN tournament_divisions d ON d.id = e.division_id LEFT JOIN team_members g ON g.id = $2 AND g.team_id = tm.id "
    "WHERE e.manage_key_hash = $1 LIMIT 1",
    "={{ [$json.hash, $json.member || 0] }}", [660, -100], always=True))
n.append(code("Plan", r"""
const s = $json, r = $('Check Request').first().json;
const fail = (m, status = 422) => [{ json: { ok: false, status, body: { success: false, message: m } } }];
if (!s.eid) return fail('This link is not valid. Use the link you got after registering.', 404);
const parse = v => { if (v == null) return null; if (typeof v === 'object') return v; try { return JSON.parse(v); } catch { return null; } };
if (r.action === 'LOAD') {
  const members = (parse(s.members) || []).map(m => ({ ...m, in_squad: Number(m.in_squad) === 1 }))
    .sort((a, b) => (a.status === b.status ? a.id - b.id : a.status === 'PENDING' ? -1 : 1));
  return [{ json: { ok: true, mode: 'LOAD', data: { tournament: { code: s.tcode, name: s.tname, start_date: s.start_date, started: Number(s.started) === 1, slug: s.slug },
    team: { code: s.team_code, name: s.team_name, status: s.estatus, division: s.dname, min_age: s.min_age, max_age: s.max_age, squad_min: s.squad_min, squad_max: s.squad_max,
      paid_players: Number(s.paid_players || 0), squad_count: Number(s.squad_count), amount: Number(s.amount), reject_reason: s.reject_reason || null },
    fee_per_player: Number(s.fee_per_player || 0), members, payments: parse(s.payments) || [] } } }];
}
if (['REJECTED', 'WITHDRAWN'].includes(s.estatus)) return fail(`${s.team_name} is no longer registered, so the squad can't be changed.`, 409);
if (Number(s.started) === 1) return fail('The tournament has started, so the squad can no longer be changed.', 409);
const p = [], st = [];
const add = v => { p.push(v); return '$' + p.length; };
let message;
if (['APPROVE', 'REJECT', 'REMOVE'].includes(r.action)) {
  if (!s.tgt_id) return fail('That player is no longer in the list. Refresh the page.', 404);
  const first = String(s.tgt_name || 'This player').split(' ')[0];
  if (r.action === 'APPROVE') {
    if (s.tgt_status !== 'PENDING') return fail(`${first} is already in the squad.`, 409);
    const age = Number(s.tgt_age);
    if (s.max_age != null && age > s.max_age) return fail(`${first} will be ${age} on ${s.day}, too old for ${s.dname}.`);
    if (s.min_age != null && age < s.min_age) return fail(`${first} will be ${age} on ${s.day}, too young for ${s.dname}.`);
    if (Number(s.squad_count) >= Number(s.squad_max)) return fail(`${s.dname} squads can have up to ${s.squad_max} players. Remove someone first.`, 409);
    if (Number(s.squad_count) >= Number(s.paid_players || 0))
      return fail(`You've paid for ${s.paid_players} players and all places are used. Pay for extra players to add ${first}.`, 409);
    st.push(`UPDATE team_members SET status = 'ACTIVE' WHERE id = ${add(s.tgt_id)} AND status = 'PENDING'`);
    st.push(`INSERT INTO tournament_entry_players (entry_id, tournament_id, team_member_id, user_id, jersey_number) VALUES (${add(s.eid)}, ${add(s.tid)}, ${add(s.tgt_id)}, NULL, ${add(s.tgt_jersey)})`);
    message = `${first} is in the squad.`;
  } else if (r.action === 'REJECT') {
    if (s.tgt_status !== 'PENDING') return fail(`${first} is already in the squad. Use Remove instead.`, 409);
    st.push(`UPDATE team_members SET status = 'REMOVED' WHERE id = ${add(s.tgt_id)} AND status = 'PENDING'`);
    message = `${first}'s request was declined.`;
  } else {
    if (s.tgt_status !== 'ACTIVE' || s.tgt_user) return fail(`${first} can't be removed here.`, 409);
    st.push(`DELETE FROM tournament_entry_players WHERE entry_id = ${add(s.eid)} AND team_member_id = ${add(s.tgt_id)}`);
    st.push(`UPDATE team_members SET status = 'REMOVED' WHERE id = ${add(s.tgt_id)}`);
    message = `${first} was removed from the squad.`;
  }
  return [{ json: { ok: true, mode: 'RUN', has_files: false, sql: st.join('; '), params: p, message } }];
}
// PAY_EXTRA
const paid = Number(s.paid_players || 0), fee = Number(s.fee_per_player || 0) * r.extra;
if (paid + r.extra > Number(s.squad_max))
  return fail(`${s.dname} squads can have up to ${s.squad_max} players. You've paid for ${paid}, so you can add up to ${Math.max(0, s.squad_max - paid)} more.`);
const files = r.files.map(f => ({ ...f, key: `payment_proof/${s.coach_phone}/payment_proof_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${f.ext}` }));
const proof = files[0] ? files[0].key : null;
st.push(`INSERT INTO entry_payments (entry_id, players, amount, utr, proof_key) VALUES (${add(s.eid)}, ${add(r.extra)}, ${add(fee)}, ${add(r.utr)}, ${add(proof)})`);
st.push(`UPDATE tournament_entries SET paid_players = COALESCE(paid_players, 0) + ${add(r.extra)}, amount = amount + ${add(fee)}, ` +
  `utr = COALESCE(${add(r.utr)}, utr), proof_key = COALESCE(${add(proof)}, proof_key), payment_claimed_at = NOW() WHERE id = ${add(s.eid)}`);
const inr = v => '₹' + Number(v).toLocaleString('en-IN');
st.push(`INSERT INTO notifications (user_id, type, title, body, data) VALUES (${add(s.organizer_user_id)}, 'ENTRY', ${add(`${s.team_name} paid for ${r.extra} more ${r.extra === 1 ? 'player' : 'players'}`)}, ` +
  `${add(`Paid ${inr(fee)} by UPI${r.utr ? ` (UTR ${r.utr})` : ''}. ${s.team_name} has now paid for ${paid + r.extra} players. Check the payment in the Teams tab.`)}, ` +
  `JSON_OBJECT('tournament_code', ${add(s.tcode)}))`);
return [{ json: { ok: true, mode: 'RUN', has_files: files.length > 0, files, sql: st.join('; '), params: p,
  message: `Thanks! You've paid for ${r.extra} more ${r.extra === 1 ? 'player' : 'players'}. You can now approve up to ${paid + r.extra} players.` } }];""", [880, -100]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1100, -100]))
n.append(iff("Load?", "={{ $json.mode === 'LOAD' }}", [1320, -100]))
# LOAD: sign player photos (team_assets/) for an hour.
n.append(code("B2 Load Credentials", B2_AUTH, [1540, -600]))
n.append(http("Authorize B2 Load", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [1740, -600]))
n.append(http("Photos Link", "POST", "={{ $('Authorize B2 Load').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_download_authorization",
              [("Authorization", "={{ $('Authorize B2 Load').first().json.authorizationToken }}"), ("Content-Type", "application/json")], [1940, -600],
              json_body="={{ JSON.stringify({ bucketId: '" + BUCKET_ID + "', fileNamePrefix: 'team_assets/', validDurationInSeconds: 3600 }) }}"))
for x in n:
    if x["name"] in ("Photos Link", "Authorize B2 Load"):
        x["onError"] = "continueRegularOutput"
n.append(code("Build Load", r"""
const d = $('Plan').first().json.data;
const b2 = $('Authorize B2 Load').first().json, t = $json.authorizationToken;
const dl = b2 && b2.apiInfo ? b2.apiInfo.storageApi.downloadUrl : null;
const sign = k => k && dl && t && k.startsWith('team_assets/') ? `${dl}/file/""" + BUCKET_NAME + r"""/${k.split('/').map(encodeURIComponent).join('/')}?Authorization=${t}` : null;
const members = d.members.map(({ photo_key, ...m }) => ({ ...m, photo_url: sign(photo_key) }));
return [{ json: { status: 200, body: { success: true, ...d, members } } }];""", [2140, -600]))
# RUN: optional payment screenshot upload (PAY_EXTRA), then the SQL.
n.append(iff("Has Files?", "={{ $json.has_files }}", [1540, -100]))
n.append(code("Files", r"""
const r = $('Check Request').first(), p = $('Plan').first().json;
return p.files.map(f => ({ json: f, binary: { file: r.binary[f.field] } }));""", [1760, -300]))
n.append(code("B2 Credentials", B2_AUTH, [1960, -300]))
au = http("Authorize B2", "GET", "https://api.backblazeb2.com/b2api/v4/b2_authorize_account", [("Authorization", "={{ $json.basicAuth }}")], [2160, -300])
au["executeOnce"] = True
n.append(au)
n.append(code("Each File", "return $('Files').all().map(i => ({ json: i.json }));", [2260, -150]))
n.append(http("Upload URL", "GET", "={{ $('Authorize B2').first().json.apiInfo.storageApi.apiUrl }}/b2api/v4/b2_get_upload_url?bucketId=" + BUCKET_ID,
              [("Authorization", "={{ $('Authorize B2').first().json.authorizationToken }}")], [2360, -300]))
n.append(code("Attach", r"""
const files = $('Files').all();
return $input.all().map((u, i) => ({ json: { uploadUrl: u.json.uploadUrl, uploadToken: u.json.authorizationToken, mime: files[i].json.mime,
  name: files[i].json.key.split('/').map(encodeURIComponent).join('/') }, binary: { file: files[i].binary.file } }));""", [2560, -300]))
up = http("Upload", "POST", "={{ $json.uploadUrl }}",
          [("Authorization", "={{ $json.uploadToken }}"), ("X-Bz-File-Name", "={{ $json.name }}"),
           ("Content-Type", "={{ $json.mime }}"), ("X-Bz-Content-Sha1", "do_not_verify")],
          [2760, -300], binary_field="file", never_error=True)
up.update(retryOnFail=True, maxTries=3, waitBetweenTries=1000)
n.append(up)
n.append(code("All Uploaded", "return [{ json: { ok: $input.all().every(i => i.json.statusCode === 200) } }];", [2960, -300]))
n.append(iff("Uploaded?", "={{ $json.ok }}", [3160, -300]))
save_and_respond(n, c, 3380, r"""
return [{ json: { status: 200, body: { success: true, message: p.message } } }];""")
n.append(respond([3900, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Load?", 0); link(c, "Plan OK?", "Respond", 1)
link(c, "Load?", "B2 Load Credentials", 0); link(c, "Load?", "Has Files?", 1)
link(c, "B2 Load Credentials", "Authorize B2 Load"); link(c, "Authorize B2 Load", "Photos Link"); link(c, "Photos Link", "Build Load"); link(c, "Build Load", "Respond")
link(c, "Has Files?", "Files", 0); link(c, "Has Files?", "Save", 1)
link(c, "Files", "B2 Credentials"); link(c, "B2 Credentials", "Authorize B2"); link(c, "Authorize B2", "Each File"); link(c, "Each File", "Upload URL")
link(c, "Upload URL", "Attach"); link(c, "Attach", "Upload"); link(c, "Upload", "All Uploaded"); link(c, "All Uploaded", "Uploaded?")
link(c, "Uploaded?", "Save", 0); link(c, "Uploaded?", "Upload Failed", 1)
out['public_team_manage'] = workflow("PubTeamMg026mPxH", "MyPaltan v2 - Public Team Manage", n, c)

for k, w in out.items():
    json.dump(w, open(os.path.join(OUT, f'{k}.json'), 'w'), indent=2)
    print(k, w['id'], len(w['nodes']), 'nodes')
json.dump({f"{k}::{nd['name']}": nd['parameters']['jsCode'] for k, w in out.items() for nd in w['nodes'] if nd['type'].endswith('.code')},
          open(os.path.join(HERE, '_codes_web_registration.json'), 'w'))
