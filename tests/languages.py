import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
catalogs = {code: json.loads((root / 'Languages' / (code + '.json')).read_text(encoding='utf-8'))
            for code in ('uk-UA', 'en-US')}
uk, en = catalogs['uk-UA'], catalogs['en-US']
assert uk.keys() == en.keys(), 'Catalog keys differ'
for key, value in uk.items():
    assert isinstance(value, str) and isinstance(en[key], str)
    if key != '_language':
        assert re.findall(r'%(?:\d+:)?[-\d.]*[a-zA-Z%]', value) == re.findall(r'%(?:\d+:)?[-\d.]*[a-zA-Z%]', en[key]), key
for file in (root / 'src').rglob('*.pas'):
    source = file.read_text(encoding='utf-8-sig')
    for key in re.findall(r"(?:L|LF)\('([^']+)'\s*,", source):
        assert key in uk, (file, key)
assert not any(re.search('[\u0400-\u04ff]', value) for value in en.values()), 'Untranslated English entries'
print('PASS: both UTF-8 language catalogs, stable keys, source lookups, matching format placeholders')
