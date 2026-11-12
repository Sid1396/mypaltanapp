"""Builds the account workflows used by the app's Profile page.

  python3 build_account.py   → writes ../workflows/v2/account_delete.json

Delete account (required by the App Store and Play Store): the person's personal data is removed at once and they
are logged out. Their row in app_users stays (teams, tournaments and entries point at it) but shows "Deleted user",
and the phone number is freed so they could sign up again later as a new person.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'build_staff_tournament.py')).read().split('\nout = {}\n')[0])  # helpers
APP_AUTH = open(os.path.join(HERE, '_app_auth.js')).read()

out = {}

n, c = [], {}
n.append(webhook("v2/users/delete-account", "POST"))
n.append(code("Check Request", APP_AUTH + r"""
const auth = verifyToken($in.headers);
if (!auth.ok) return [{ json: { ok: false, status: 401, body: { success: false, message: auth.error } } }];
// The app asks the person to confirm first and sends this word, so a stray call can't delete an account.
if (String(($in.body || {}).confirm || '') !== 'DELETE') return [{ json: { ok: false, status: 422, body: { success: false, message: 'Please confirm that you want to delete your account.' } } }];
return [{ json: { ok: true, phone: auth.phone } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load User",
    "SELECT u.id, u.phone, u.photo_key, (SELECT JSON_ARRAYAGG(JSON_ARRAY(v.id_front_key, v.id_back_key, v.selfie_key)) FROM identity_verifications v WHERE v.user_id = u.id) AS id_files "
    "FROM app_users u WHERE u.phone = $1 AND u.is_active = 1",
    "={{ [$json.phone] }}", [660, -100], always=True))
n.append(code("Plan", r"""
const u = $json;
if (!u.id) return [{ json: { ok: false, status: 404, body: { success: false, message: 'This account no longer exists.' } } }];
let ids = [];
try { ids = (typeof u.id_files === 'string' ? JSON.parse(u.id_files) : u.id_files) || []; } catch (e) {}
// Only this person's own files: profile photo and ID-check photos.
const files = [u.photo_key, ...ids.flat()].filter(k => typeof k === 'string' && k && !k.includes('..'));
const id = Number(u.id);
// All in one transaction: either everything personal is gone or nothing changes.
const sql = [
  'START TRANSACTION',
  'DELETE FROM app_user_sports WHERE user_id = $1',
  'DELETE FROM coach_web_pins WHERE user_id = $2',
  'DELETE FROM identity_verifications WHERE user_id = $3',
  'DELETE FROM notifications WHERE user_id = $4',
  'DELETE FROM tournament_scorers WHERE user_id = $5',
  // Out of squads for tournaments that haven't started; finished matches keep their history.
  'DELETE ep FROM tournament_entry_players ep JOIN tournaments t ON t.id = ep.tournament_id WHERE ep.user_id = $6 AND t.start_date > CURDATE()',
  "UPDATE team_members SET status = 'REMOVED' WHERE user_id = $7",
  'DELETE FROM otp_sessions WHERE phone = $8',
  // The row stays for teams / tournaments / entries that point at it; the phone becomes a placeholder that can't log in.
  "UPDATE app_users SET phone = CONCAT('0', LPAD(id, 9, '0')), name = 'Deleted user', birthdate = NULL, gender = NULL, jersey_name = NULL, " +
    'jersey_number = NULL, jersey_size = NULL, food_pref = NULL, photo_key = NULL, pincode = NULL, area = NULL, city = NULL, state = NULL, ' +
    'profile_complete = 0, is_verified = 0, is_active = 0 WHERE id = $9',
  'COMMIT',
].join('; ');
return [{ json: { ok: true, sql, params: [id, id, id, id, id, id, id, u.phone, id], files } }];""", [880, -100]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1100, -100]))
n.append(mysql("Delete Data", "={{ $json.sql }}", "={{ $json.params }}", [1320, -200], continue_on_error=True))
n.append(code("Delete Files", r"""
// Removes the person's photos from storage. A failure here doesn't undo the deletion (the links are gone from the database).
const plan = $('Plan').first().json;
const dbError = $json.error || /ER_|syntax/i.test(String($json.message || ''));
if (dbError || !plan.files.length) return [{ json: { dbError: !!dbError, deleted: 0 } }];
let deleted = 0;
try {
  const auth = await this.helpers.httpRequest({ method: 'GET', url: 'https://api.backblazeb2.com/b2api/v4/b2_authorize_account',
    headers: { Authorization: 'Basic ' + Buffer.from(`${$env.B2_KEY_ID}:${$env.B2_APPLICATION_KEY}`).toString('base64') }, json: true });
  const api = auth.apiInfo.storageApi.apiUrl, H = { Authorization: auth.authorizationToken };
  for (const name of plan.files) {
    const l = await this.helpers.httpRequest({ method: 'POST', url: `${api}/b2api/v4/b2_list_file_versions`, headers: H, json: true,
      body: { bucketId: '""" + BUCKET_ID + r"""', startFileName: name, prefix: name, maxFileCount: 10 } });
    for (const f of (l.files || []).filter(f => f.fileName === name)) {
      await this.helpers.httpRequest({ method: 'POST', url: `${api}/b2api/v4/b2_delete_file_version`, headers: H, json: true, body: { fileName: f.fileName, fileId: f.fileId } });
      deleted++;
    }
  }
} catch (e) {}
return [{ json: { dbError: false, deleted } }];""", [1540, -200]))
n.append(code("Build Response", r"""
if ($json.dbError) return [{ json: { status: 500, body: { success: false, message: 'Could not delete your account. Please try again.' } } }];
return [{ json: { status: 200, body: { success: true, message: 'Your account and personal data have been deleted.' } } }];""", [1760, -200]))
n.append(respond([1980, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load User", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load User", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Delete Data", 0); link(c, "Plan OK?", "Respond", 1)
link(c, "Delete Data", "Delete Files"); link(c, "Delete Files", "Build Response"); link(c, "Build Response", "Respond")
out['account_delete'] = workflow("AcctDelete026mPx", "MyPaltan v2 - Delete Account", n, c)

# ───────────── Featured league: "Notify me when registration opens" (toggle) ─────────────
n, c = [], {}
n.append(webhook("v2/featured/interest", "POST"))
n.append(code("Check Request", APP_AUTH + r"""
const auth = verifyToken($in.headers);
if (!auth.ok) return [{ json: { ok: false, status: 401, body: { success: false, message: auth.error } } }];
const b = $in.body || {};
const slug = String(b.slug || '').toLowerCase();
if (!/^[a-z0-9-]{2,80}$/.test(slug)) return [{ json: { ok: false, status: 422, body: { success: false, message: 'Unknown league.' } } }];
return [{ json: { ok: true, phone: auth.phone, slug, interested: b.interested !== false } }];""", [220, 0]))
n.append(iff("Valid?", "={{ $json.ok }}", [440, 0]))
n.append(mysql("Load", "SELECT (SELECT id FROM app_users WHERE phone = $1 AND is_active = 1) AS uid, "
    "(SELECT status FROM featured_tournaments WHERE slug = $2 AND is_active = 1) AS fstatus",
    "={{ [$json.phone, $json.slug] }}", [660, -100], always=True))
n.append(code("Plan", r"""
const s = $json, r = $('Check Request').first().json;
const fail = (st, m) => [{ json: { ok: false, status: st, body: { success: false, message: m } } }];
if (!s.uid) return fail(401, 'Please log in again.');
if (!s.fstatus) return fail(404, 'This league is no longer listed.');
return [{ json: { ok: true, interested: r.interested,
  sql: r.interested ? 'INSERT IGNORE INTO featured_interest (slug, user_id) VALUES ($1, $2)' : 'DELETE FROM featured_interest WHERE slug = $1 AND user_id = $2',
  params: [r.slug, Number(s.uid)] } }];""", [880, -100]))
n.append(iff("Plan OK?", "={{ $json.ok }}", [1100, -100]))
n.append(mysql("Save", "={{ $json.sql }}", "={{ $json.params }}", [1320, -200], continue_on_error=True))
n.append(code("Build Response", r"""
if ($json.error || /ER_|syntax/i.test(String($json.message || ''))) return [{ json: { status: 500, body: { success: false, message: 'Could not save. Please try again.' } } }];
const on = $('Plan').first().json.interested;
return [{ json: { status: 200, body: { success: true, interested: on,
  message: on ? "You'll get a notification when registration opens." : "You won't be notified for this league." } } }];""", [1540, -200]))
n.append(respond([1760, 0]))
link(c, "Webhook", "Check Request"); link(c, "Check Request", "Valid?")
link(c, "Valid?", "Load", 0); link(c, "Valid?", "Respond", 1)
link(c, "Load", "Plan"); link(c, "Plan", "Plan OK?")
link(c, "Plan OK?", "Save", 0); link(c, "Plan OK?", "Respond", 1)
link(c, "Save", "Build Response"); link(c, "Build Response", "Respond")
out['featured_interest'] = workflow("FeatIntrst026mPx", "MyPaltan v2 - Featured Interest", n, c)

# ───────────── Every 30 minutes: tell interested people when a featured league opens registration ─────────────
n, c = [], {}
n.append(node("Every 30 Minutes", "n8n-nodes-base.scheduleTrigger", 1.2, (0, 0),
              {"rule": {"interval": [{"field": "minutes", "minutesInterval": 30}]}}))
# One notification per person, then the interest list for that league is cleared so nobody is told twice.
n.append(mysql("Notify And Clear",
    "START TRANSACTION; "
    "INSERT INTO notifications (user_id, type, title, body, data) "
    "SELECT fi.user_id, 'TOURNAMENT', LEFT(CONCAT(f.name, ': registration is open'), 120), "
    "'Registration is open on MyPaltan. Open the Tournaments tab to register your team.', JSON_OBJECT('featured_slug', f.slug) "
    "FROM featured_interest fi JOIN featured_tournaments f ON f.slug = fi.slug WHERE f.status = 'REGISTRATION_OPEN' AND f.is_active = 1; "
    "DELETE fi FROM featured_interest fi JOIN featured_tournaments f ON f.slug = fi.slug WHERE f.status = 'REGISTRATION_OPEN' AND f.is_active = 1; "
    "COMMIT",
    "", [220, 0], continue_on_error=True))
link(c, "Every 30 Minutes", "Notify And Clear")
out['featured_notify'] = workflow("FeatNotify026mPx", "MyPaltan v2 - Featured Registration Notify", n, c)

for k, w in out.items():
    json.dump(w, open(os.path.join(OUT, f'{k}.json'), 'w'), indent=2)
    print(k, w['id'], len(w['nodes']), 'nodes')
