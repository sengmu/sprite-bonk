#!/usr/bin/env python3
"""Data contract + independent bundle-table comparison; no fusion gameplay."""
import json
import copy
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]

def validate(data, rules):
    rows = data['entries']
    assert Counter(x['kind'] for x in rows) == {'signature': 79, 'reaction': 8, 'type': 18, 'glitch': 1}
    assert len({x['key'] for x in rows}) == 106
    pokemon = {x['id']: x for x in json.loads((ROOT/'assets/data/pokemon.json').read_text())}
    moves = {x['key']: x for x in json.loads((ROOT/'assets/data/moves.json').read_text())}
    for i, row in enumerate(rows):
        assert row['id'] == 50000+i
        assert row['runtime']['arch'] == 'fusion'
        assert abs(row['runtime']['dmg'] - 17*row['power']) < 1e-10
        assert row['cd'] > 0 and row['power'] > 0
        if row['kind'] == 'signature':
            assert row['member_key'] == pokemon[row['member']]['key']
            assert len(row['moves']) == 2 and all(k in moves for k in row['moves'])
    by = {x['key']: x for x in rows}
    assert by['fu-r-nightmare']['pair'] == [['psychic', 'grass'], ['ghost', 'dark']]
    assert by['fu-r-shatter']['pair'] == [['ice'], ['fighting', 'rock', 'steel']]
    assert by['fu-95']['raw']['power_override'] == 11.83
    assert rules['parent_min_level'] == 8
    assert rules['resolve_order'] == ['signature', 'reaction', 'type', 'glitch']
    assert rules['mods_merge']['cd'] == 'a*b'
    assert rules['mods_merge']['dmg'] == 'a+b-1'
    assert rules['damage']['level_add'] == 0.04 and rules['damage']['multiplier'] == 1.3
    assert rules['result']['timer'] == 1.2

if __name__ == '__main__':
    data = json.loads((ROOT/'assets/data/fusions.json').read_text())
    rules = json.loads((ROOT/'assets/data/fusion_rules.json').read_text())
    validate(data, rules)
    print('C24 fusion data: contract PASS (106 entries)')
    mutations = [
        lambda d,r: d['entries'].pop(),
        lambda d,r: d['entries'][0].update(id=50001),
        lambda d,r: d['entries'][0]['runtime'].update(dmg=0),
        lambda d,r: d['entries'][0].update(member_key='kabuto'),
        lambda d,r: next(x for x in d['entries'] if x['key']=='fu-r-nightmare').update(pair=[['psychic'],['dark']]),
        lambda d,r: r.update(parent_min_level=7),
        lambda d,r: r['mods_merge'].update(cd='a+b-1'),
        lambda d,r: r['result'].update(timer=0.4),
    ]
    for mutation in mutations:
        d,r = copy.deepcopy(data),copy.deepcopy(rules)
        mutation(d,r)
        try:
            validate(d,r)
        except AssertionError:
            continue
        raise AssertionError('missed mutation')
    print('C24 fusion mutation checks: 8 killed / 0 missed')
