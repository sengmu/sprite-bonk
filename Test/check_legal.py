#!/usr/bin/env python3
"""Verify bundled text against site visible copy; no network, no rewriting."""
import argparse
import hashlib
import html
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path)
args = parser.parse_args()
manifest = json.loads((root / 'assets/legal/provenance.json').read_text())
source = args.source.read_text() if args.source else None
if source:
    assert hashlib.sha256(source.encode()).hexdigest() == manifest['sha256'], 'site source changed'
for doc, variable in [('privacy', 'PRIVACY_HTML'), ('terms', 'TERMS_HTML')]:
    expected = {}
    if source:
        body = re.search(r'const ' + variable + r' = `(.*?)`;', source, re.S)[1]
        for key, value in [('PUBLISHER', '林贵鸿'), ('SUPPORT_EMAIL', 'linguihong000@gmail.com'), ('EFFECTIVE', 'October 25, 2026')]:
            body = body.replace('${' + key + '}', value)
        body = body.split('<body>')[1].split('</body>')[0]
        for lang, part in zip(['en', 'zh'], body.split('<hr>')):
            part = re.sub(r'<br\s*/?>', '\n', part)
            part = re.sub(r'</(?:p|h1|h2|h3|li)>', '\n\n', part)
            expected[lang] = re.sub(r'\n{3,}', '\n\n', html.unescape(re.sub('<[^>]+>', '', part))).strip()
    for lang in ['en', 'zh']:
        name = f'{doc}_{lang}'
        resource = (root / f'assets/legal/{name}.tres').read_text()
        text = json.loads(resource.split('text = ', 1)[1].strip())
        digest = hashlib.sha256(text.encode()).hexdigest()
        assert digest == manifest['text_sha256'][name], name + ' text changed'
        if source:
            assert text == expected[lang], name + ' differs from site visible copy'
        if doc == 'terms':
            phrases = ['not a party', 'no less protective', 'Sections 13 and 14'] if lang == 'en' else ['不是本条款的当事方', '不低于', '第 13 条与第 14 条']
            for phrase in phrases:
                assert phrase in text, f'{name}: missing {phrase}'
        print(f'LEGAL OK {name} chars={len(text)} sha256={digest}')
print('LEGAL DONE 4/4 exact; policy §10.6 obligations present in both languages')
