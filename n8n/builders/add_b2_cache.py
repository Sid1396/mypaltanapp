"""Reuses the Backblaze B2 image links for 20 hours instead of asking B2 on every request.

  python3 add_b2_cache.py home match_detail ...   → patches ../workflows/v2/<name>.json in place (safe to run again)

Why: each request used to call b2_authorize_account and one b2_get_download_authorization per folder (2-4 B2 "class C"
transactions). Screens that refresh every few seconds (the stream score overlay, live match pages) used up B2's daily
transaction cap, and then every photo and logo in the app and on the website broke.

How: B2 Credentials also says whether this workflow's saved links (workflow static data) are still fresh. If they are,
"B2 Fresh?" skips the B2 calls; otherwise they run as before. "B2 Ready" returns the links either way (and saves fresh
ones). The code after it reads $('Authorize B2') / $('<X> Link') through a small wrapper, so it works unchanged.
B2 issues the links for 24 hours; they are reused for 20, so a link handed out is good for at least 4 more hours.
"""
import json
import os
import re
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'workflows', 'v2')
FRESH_HOURS = 20


def _id():
    return str(uuid.uuid4())


def add_b2_cache(w):
    nodes = {n['name']: n for n in w['nodes']}
    conns = w['connections']
    if 'B2 Ready' in nodes:
        return False  # already done
    if 'B2 Credentials' not in nodes or 'Authorize B2' not in nodes:
        raise ValueError(f"{w['name']}: no B2 Credentials / Authorize B2")

    # The chain: B2 Credentials → Authorize B2 → X Link → Y Link → … → next.
    def after(name):
        outs = conns.get(name, {}).get('main', [[]])
        return [c['node'] for c in (outs[0] if outs else [])]

    assert after('B2 Credentials') == ['Authorize B2'], after('B2 Credentials')
    links, cur = [], 'Authorize B2'
    while True:
        nxt = after(cur)
        if len(nxt) == 1 and nodes[nxt[0]]['type'].endswith('httpRequest') and 'download_authorization' in json.dumps(nodes[nxt[0]]['parameters']):
            links.append(nxt[0])
            cur = nxt[0]
            continue
        break
    targets = conns[cur]['main'][0]
    assert links, 'no link nodes'
    names = json.dumps(links)

    cred = nodes['B2 Credentials']
    cred['parameters']['jsCode'] = (
        "// Fresh saved B2 links (add_b2_cache.py): skip the B2 calls.\n"
        "const saved = $getWorkflowStaticData('global').b2;\n"
        f"const b2Fresh = !!(saved && Date.now() - saved.at < {FRESH_HOURS} * 3600e3 && {names}.every(n => saved.links && saved.links[n]));\n"
        "return [{ json: { basicAuth: 'Basic ' + Buffer.from(`${$env.B2_KEY_ID}:${$env.B2_APPLICATION_KEY}`).toString('base64'), b2Fresh } }];"
    )
    x, y = cred['position']
    fresh = {"parameters": {"conditions": {
        "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "loose", "version": 2},
        "conditions": [{"id": _id(), "leftValue": "={{ $json.b2Fresh }}", "rightValue": "",
                        "operator": {"type": "boolean", "operation": "true", "singleValue": True}}],
        "combinator": "and"}, "options": {}},
        "name": "B2 Fresh?", "type": "n8n-nodes-base.if", "typeVersion": 2.2, "position": [x + 110, y + 180], "id": _id()}
    lx, ly = nodes[cur]['position']
    ready = {"parameters": {"jsCode": (
        "// The B2 links: saved ones while fresh, else the ones just fetched (saved for next time when all succeeded).\n"
        "const store = $getWorkflowStaticData('global');\n"
        "if ($('B2 Credentials').first().json.b2Fresh) return [{ json: { acct: store.b2.acct, links: store.b2.links } }];\n"
        "const a = $('Authorize B2').first().json;\n"
        "const acct = { apiInfo: a.apiInfo, authorizationToken: a.authorizationToken };\n"
        "const links = {};\n"
        f"for (const n of {names}) {{ try {{ const t = $(n).first().json.authorizationToken; if (t) links[n] = {{ authorizationToken: t }}; }} catch {{}} }}\n"
        f"if (acct.authorizationToken && acct.apiInfo && Object.keys(links).length === {len(links)}) store.b2 = {{ at: Date.now(), acct, links }};\n"
        "return [{ json: { acct, links } }];"
    )}, "name": "B2 Ready", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [lx + 110, ly + 180], "id": _id()}
    w['nodes'] += [fresh, ready]

    conns['B2 Credentials'] = {'main': [[{'node': 'B2 Fresh?', 'type': 'main', 'index': 0}]]}
    conns['B2 Fresh?'] = {'main': [[{'node': 'B2 Ready', 'type': 'main', 'index': 0}], [{'node': 'Authorize B2', 'type': 'main', 'index': 0}]]}
    conns[cur] = {'main': [[{'node': 'B2 Ready', 'type': 'main', 'index': 0}]]}
    conns['B2 Ready'] = {'main': [targets]}

    # Code that reads the B2 nodes gets them through the wrapper (they do not run when the saved links are used).
    b2_names = ['Authorize B2'] + links
    wrap = (
        "const __b2 = $('B2 Ready').first().json; // B2 links, saved or fresh (add_b2_cache.py)\n"
        "const __$ = n => n === 'Authorize B2' || __b2.links[n] ? (j => ({ isExecuted: true, first: () => ({ json: j }), all: () => [{ json: j }] }))(n === 'Authorize B2' ? __b2.acct : __b2.links[n]) : $(n);\n"
    )
    patched = []
    for n in w['nodes']:
        js = n['parameters'].get('jsCode')
        if n['name'] in ('B2 Credentials', 'B2 Ready') or not js:
            continue
        if not any(f"'{b}'" in js or f'"{b}"' in js for b in b2_names) and 'tokenOf(' not in js:
            continue
        n['parameters']['jsCode'] = wrap + re.sub(r'(?<![\w$])\$\(', '__$(', js)
        patched.append(n['name'])
    for t in targets:
        js = nodes[t['node']]['parameters'].get('jsCode', '')
        if re.search(r'\$input\b|\$json\b|\$in\b', js.replace('const $in = $input.first().json;', '')):
            print(f"  ! {w['name']} / {t['node']} reads its input item; check it")
    print(f"  {w['name']}: links {links} → {[t['node'] for t in targets]}; code patched: {patched}")
    return True


if __name__ == '__main__':
    for name in sys.argv[1:]:
        p = os.path.join(OUT, f'{name}.json')
        raw = open(p).read()
        w = json.loads(raw)
        if add_b2_cache(w):
            open(p, 'w').write(json.dumps(w, indent=2) + ('\n' if raw.endswith('\n') else ''))
