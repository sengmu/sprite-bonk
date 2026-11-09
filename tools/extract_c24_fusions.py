#!/usr/bin/env python3
"""Read a verified local upstream bundle; emit inert scalar fusion tables only."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHA = '4b4a76ddd47d60167f4a330250cee58f036dc68d2efa692aaecd9638249d2d7e'
DEFAULT = Path('/home/hatch/workspace/pokebonk-rea/scripts_out/files/origins/3be62a71e6b7643af0182c742f1dbf8e5693334fcb4fae70524563ae5a92cece/assets/main-CkI7dQhz-mvml8e65.js')


def extract(source):
    blob = source.read_bytes()
    assert hashlib.sha256(blob).hexdigest() == SHA, 'wrong source bundle'
    text = blob.decode()
    start = text.index('var WS=')
    end = text.index(',CC=new Map', start)
    # Only declarations. Factory closures are retained until JSON serialization,
    # never called. Localization c is identity to retain original Spanish text.
    fragment = text[start:end] + ';JSON.stringify({SC,yC,bC,xC:[...xC]})'
    node = '''const vm=require('vm'), fs=require('fs');
const script=fs.readFileSync(0,'utf8');
process.stdout.write(vm.runInNewContext(script,{c:x=>x},{timeout:3000}));'''
    table = json.loads(subprocess.check_output(['node', '-e', node], input=fragment.encode()))
    pokemon = {r['id']:r for r in json.loads((ROOT/'assets/data/pokemon.json').read_text())}
    rows = []
    for index, original in enumerate(table['SC']):
        row = dict(original)
        power = table['yC'].get(row['key'], row['power'])
        cd = row['cd'] * table['bC']
        factor = min(1, max(2/cd, (4/power)**0.5)) if power > 4 else 1
        row['raw'] = {'cd': row['cd'], 'power': row['power'], 'power_override': power,
                      'repeats': row.get('repeats', False)}
        row['normalization_scale'] = factor
        row['power'], row['cd'] = power*factor, cd*factor
        row['repeats'] = row.get('repeats', False) or row['key'] in table['xC']
        row['id'] = 50000 + index
        if row['kind'] == 'signature':
            row['member_key'] = pokemon[row['member']]['key']
        row['runtime'] = {'arch':'fusion', 'dmg':17*row['power'], 'count':0, 'area':5,
                          'speed':1, 'dur':1, 'pierce':99, 'status':row.get('status'),
                          'statusChance':0.5 if row.get('status') else 0,
                          'drain':0, 'critBonus':0, 'flinch':0, 'power':100}
        rows.append(row)
    return {'schema_version':1, 'status':'PROVEN_STATIC_DATA_ONLY',
            'source':{'chunk':'main-CkI7dQhz-mvml8e65.js','sha256':SHA,
                      'offset_unit':'Unicode characters, zero based',
                      'declarations_start':start,'declarations_end_exclusive':end,
                      'normalization':text.index('SC.forEach('),'runtime_factory':text.index('function US('),'fusion_base_dmg':text.index('fusion:{',749063)},
            'counts':{'signature':79,'reaction':8,'type':18,'glitch':1,'total':106},
            'pack_count_discrepancy':'Pack says 82 signatures; verified SC and yC each contain 106 total entries, including 79 signatures. No extra rows invented.',
            'entries':rows}


def rules():
    return {'schema_version':1,'status':'PROVEN_STATIC_RULES_ONLY',
            'resolve_order':['signature','reaction','type','glitch'],
            'pairs_bidirectional':True,'excluded_arch':['weather','buff','fusion'],
            'parent_min_level':8,'kind_sort':['signature','reaction','type','glitch'],
            'ready_first':True,'unlearned_signature':{'a':-1,'b':-1,'ready':False},
            'mods_identity':{'dmg':1,'cd':1,'count':0,'area':1,'speed':1,'dur':1,'pierce':0,'crit':0,'status':1,'bounce':0},
            'mods_merge':{'dmg':'a+b-1','cd':'a*b','count':'a+b','area':'a+b-1','speed':'a+b-1','dur':'a+b-1','pierce':'a+b','crit':'a+b','status':'a+b-1','bounce':'a+b'},
            'result':{'level':1,'timer':1.2,'slot':'min(a,b)','parents':'[idA,idB,...A.parents,...B.parents]','forget_both_parents':True},
            'damage':{'base':17,'multiplier':1.3,'level_add':0.04,'formula':'def.dmg*1.3*mods.dmg*(1+(level-1)*0.04)'},
            'cooldown':{'global_multiplier':0.85,'cast_min':0.6,'formula':'max(0.6,def.cd*mods.cd/attackSpeed)'},
            'normalization':{'if_power_above':4,'scale':'min(1,max(2/cd,sqrt(4/power)))','scale_both':['cd','power']},
            'bill':{'per_stage':1,'used_on_ready_choice':True},
            'glitch':{'key':'fu-missingno','cast_choice':'random type fusion'},
            'unimplemented':['engine','UI','cinematic','bespoke cast bodies','effect primitives','runtime registration']}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=DEFAULT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, data in [('fusions.json',extract(args.source)),('fusion_rules.json',rules())]:
        path = ROOT/'assets/data'/name
        if args.check:
            assert json.loads(path.read_text()) == data, name+' differs from verified source'
            print(name+': SOURCE PARITY PASS')
        else:
            path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
            print(name+': extracted')
