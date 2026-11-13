"""Builds the website scoring endpoints (mypaltan.com/score/<slug>): a backup for scorers without the app.

  python3 build_web_scoring.py
    → writes ../workflows/v2/score_web_login.json, score_web_match.json, score_web_setup.json, score_web_sync.json

Login: mobile number + name + the tournament's scoring PIN (the same PIN as in the app). It returns a scorer pass
(typ "scorer", signed with its own key) for that one tournament, valid 14 hours — not an app login, so the PIN can't
open anyone's profile or teams. The scorer is recorded in tournament_scorers like a scorer who joined in the app.

Match / setup / sync are the app's own workflows (match_detail / match_setup / match_sync, kept in sync with live),
with the app login swapped for the scorer pass and every query limited to the pass's tournament. So the rules,
scores, points tables and knockout progress are exactly the app's.
"""
import copy
import json
import os
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_web_registration.py')).read().split('\nout = {}\n')[0])  # node helpers, rate(), ORIGINS
_ca = open(os.path.join(HERE, '_coach_auth.js')).read()
SHA = _ca[:_ca.index('\n}\n', _ca.index('function hmacSha256')) + 3]  # sha256bytes + hmacSha256 (no coach-specific code)

SCORER_AUTH = SHA + r"""
function b64url(buf) { return Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, ''); }
const SCORER_KEY = () => `${$env.JWT_SECRET}|mypaltan-scorer`;
function signScorer(phone, tid) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const body = b64url(Buffer.from(JSON.stringify({ typ: 'scorer', phone, tid, iat: now, exp: now + 14 * 60 * 60 })));
  return `${header}.${body}.${b64url(hmacSha256(SCORER_KEY(), `${header}.${body}`))}`;
}
function verifyScorer(headers) {
  const auth = String((headers || {}).authorization || '').trim();
  const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  const fail = { ok: false, error: 'Please log in again with your mobile number and the scoring PIN.' };
  const parts = token.split('.');
  if (parts.length !== 3) return fail;
  const [h, p, s] = parts;
  if (b64url(hmacSha256(SCORER_KEY(), `${h}.${p}`)) !== s) return fail;
  let c;
  try { c = JSON.parse(Buffer.from(p, 'base64').toString('utf8')); } catch { return fail; }
  if (c.typ !== 'scorer' || !/^[6-9]\d{9}$/.test(String(c.phone || '')) || !Number.isInteger(c.tid)) return fail;
  if (!c.exp || c.exp < Math.floor(Date.now() / 1000)) return { ok: false, error: 'Your scoring session ended. Log in again with the PIN.' };
  return { ok: true, phone: String(c.phone), tid: c.tid };
}
"""


def load(name):
    return json.load(open(os.path.join(OUT, f'{name}.json')))


def rep(s, a, b, count=1):
    assert s.count(a) == count, (a[:80], s.count(a))
    return s.replace(a, b)


out = {}

# ───────────── Login: mobile + name + scoring PIN → scorer pass for one tournament ─────────────
n, c = [], {}
n.append(webhook("v2/public/score/login", "POST"))
n.append(code("Check Request", rate(60) + COMMON + r"""
const slug = str(b.slug).toLowerCase(), phone = str(b.phone).replace(/\D/g, '').slice(-10), pin = str(b.pin).replace(/\D/g, '');
const name = str(b.name).replace(/\s+/g, ' ');
if (!SLUG.test(slug)) return bad('This scoring link is not valid.', 404);
if (!/^[6-9]\d{9}$/.test(phone)) return bad('Enter your 10-digit mobile number.');
if (name.length < 2 || name.length > 50 || !/^[\p{L}][\p{L} .'-]*$/u.test(name)) return bad('Enter your name.');
if (!/^\d{6}$/.test(pin)) return bad('Enter the 6-digit scoring PIN from the organiser.');
// 5 wrong PINs for a number lock it for 15 minutes (same as the app).
const st = $getWorkflowStaticData('global'), t0 = Date.now();
st.fails = Object.fromEntries(Object.entries(st.fails || {}).map(([k, v]) => [k, v.filter(x => t0 - x < 15 * 60e3)]).filter(([, v]) => v.length));
if ((st.fails[phone] || []).length >= 5) return bad('Too many wrong PINs. Try again in 15 minutes.', 429);
count();
return [{ json: { ok: true, slug, phone, pin, name } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load",
    "SELECT t.id AS tid, t.name AS tname, t.sport, t.status, t.scoring_pin, t.organizer_user_id, "
    "(SELECT id FROM app_users WHERE phone = $2) AS uid, (SELECT is_active FROM app_users WHERE phone = $2) AS active "
    "FROM tournament_web_links l JOIN tournaments t ON t.id = l.tournament_id WHERE l.slug = $1",
    "={{ [$json.slug, $json.phone] }}", [660, -100], always=True))
n.append(code("Plan", r"""
const s = $json, r = $('Check Request').first().json;
const fail = (st, m) => [{ json: { ok: false, status: st, body: { success: false, message: m } } }];
if (!s.tid || s.status === 'DRAFT') return fail(404, 'This scoring link is not valid.');
if (s.sport !== 'FOOTBALL') return fail(422, 'Website scoring is only for football. Use the MyPaltan app to score.');
if (s.uid && Number(s.active) !== 1) return fail(403, 'This mobile number cannot score.');
const owner = s.uid && Number(s.uid) === Number(s.organizer_user_id);
if (!owner) {
  if (!s.scoring_pin) return fail(409, "The organiser hasn't set a scoring PIN yet.");
  if (s.scoring_pin !== r.pin) {
    const st = $getWorkflowStaticData('global');
    st.fails = st.fails || {};
    st.fails[r.phone] = [...(st.fails[r.phone] || []), Date.now()];
    return fail(403, 'Wrong PIN. Ask the organiser for the scoring PIN.');
  }
}
// New scorers get a basic MyPaltan account for their number (they can finish it in the app later).
const sql = (s.uid ? '' : 'INSERT INTO app_users (phone, name) VALUES ($1, $2); ') +
  'INSERT IGNORE INTO tournament_scorers (tournament_id, user_id) SELECT $3, id FROM app_users WHERE phone = $4';
return [{ json: { ok: true, sql, params: [r.phone, r.name, Number(s.tid), r.phone], tid: Number(s.tid), tname: s.tname } }];""", [880, -100]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1100, -100]))
n.append(mysql("Save", "={{ $json.sql }}", "={{ $json.params }}", [1320, -200], continue_on_error=True))
n.append(code("Build Response", SCORER_AUTH + r"""
if ($in.error || /ER_|syntax/i.test(String($in.message || ''))) return [{ json: { status: 500, body: { success: false, message: 'Could not log in. Please try again.' } } }];
const p = $('Plan').first().json, r = $('Check Request').first().json;
return [{ json: { status: 200, body: { success: true, token: signScorer(r.phone, p.tid), tournament: p.tname, expires_in_hours: 14 } } }];""", [1540, -200]))
n.append(respond([1760, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Save", 0); link(c, "Plan OK?", "Respond", 1)
link(c, "Save", "Build Response"); link(c, "Build Response", "Respond")
out['score_web_login'] = workflow("ScoreWebLg026mPx", "MyPaltan v2 - Web Scoring Login", n, c)


# ───────────── Match / setup / sync: the app's workflows with the scorer pass ─────────────
def web_copy(src, wid, name, path, method, ret_old, ret_new):
    w = copy.deepcopy(load(src))
    w.update(id=wid, name=name, active=False)
    nodes = {x['name']: x for x in w['nodes']}
    hook = nodes['Webhook']
    hook['webhookId'] = str(uuid.uuid4())
    hook['parameters'].update(path=path, httpMethod=method)
    hook['parameters'].setdefault('options', {})['allowedOrigins'] = ORIGINS
    js = nodes['Check Request']['parameters']['jsCode']
    js = rep(js, 'const auth = verifyToken($in.headers);', SCORER_AUTH + 'const auth = verifyScorer($in.headers);')
    js = rep(js, ret_old, ret_new)
    nodes['Check Request']['parameters']['jsCode'] = js
    ld = nodes['Load']['parameters']
    ld['query'] = rep(ld['query'], 'WHERE m.id = $2', 'WHERE m.id = $2 AND t.id = $3')   # only the pass's tournament
    ld['options']['queryReplacement'] = '={{ [$json.phone, $json.id, $json.tid] }}'
    for k in ('shared', 'tags', 'activeVersionId', 'versionCounter', 'triggerCount', 'versionMetadata', 'activeVersion', 'versionId'):
        w.pop(k, None)
    return w


out['score_web_match'] = web_copy('match_detail', 'ScoreWebMt026mPx', 'MyPaltan v2 - Web Scoring Match', 'v2/public/score/match', 'GET',
    "return [{ json: { ok: true, phone: auth.phone, id, light: $in.query?.light === '1' } }];",
    "return [{ json: { ok: true, phone: auth.phone, tid: auth.tid, id, light: $in.query?.light === '1' } }];")
out['score_web_setup'] = web_copy('match_setup', 'ScoreWebSt026mPx', 'MyPaltan v2 - Web Scoring Setup', 'v2/public/score/setup', 'POST',
    "return [{ json: { ok: true, phone: auth.phone, id, toss, decision, lineups } }];",
    "return [{ json: { ok: true, phone: auth.phone, tid: auth.tid, id, toss, decision, lineups } }];")
out['score_web_sync'] = web_copy('match_sync', 'ScoreWebSy026mPx', 'MyPaltan v2 - Web Scoring Sync', 'v2/public/score/sync', 'POST',
    "return [{ json: { ok: true, phone: auth.phone, id, base, events, live, takeOver: b.take_over === true, release: b.release === true } }];",
    "return [{ json: { ok: true, phone: auth.phone, tid: auth.tid, id, base, events, live, takeOver: b.take_over === true, release: b.release === true } }];")

for k, w in out.items():
    json.dump(w, open(os.path.join(OUT, f'{k}.json'), 'w'), indent=2)
    print(k, w['id'], len(w['id']), len(w['nodes']), 'nodes')
