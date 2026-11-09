#!/usr/bin/env python3
"""Exercise meaningful fossil mutants without modifying the working game script."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'scripts/fossils.gd'
GODOT = Path(os.environ.get('GODOT', str(Path.home() / 'workspace/tools/godot/Godot_v4.3-stable_linux.x86_64')))
MUTANT = ROOT / '.tmp/c24_fossils_mutant.gd'
LOGDIR = ROOT / 'Test/out'
LOGDIR.mkdir(parents=True, exist_ok=True)
MUTANT.parent.mkdir(exist_ok=True)
source = SOURCE.read_text()
cases = [
    ('helix_cost', '"cost":.15', '"cost":.05'),
    ('dome_cost', '"cost":.20', '"cost":.10'),
    ('amber_gate', 'or not bool(DATA[key].buildable)', 'or false'),
    ('reuse', 'if bool(prop.get("used",false)) or not DATA.has(key)', 'if false or not DATA.has(key)'),
    ('delay', 'world._later(.8,func()', 'world._later(.2,func()'),
    ('helix_floor', 'world._roll_chest_item(3,2)', 'world._roll_chest_item(2,2)'),
    ('helix_count', 'world._roll_chest_item(3,2)', 'world._roll_chest_item(3,1)'),
    ('dome_rarity', '远古祝福",4,3,1,1.5)', '远古祝福",3,3,1,1.5)'),
    ('dome_power', '远古祝福",4,3,1,1.5)', '远古祝福",4,3,1,1.0)'),
    ('reset', 'carving.visible = true', 'carving.visible = false'),
    ('counter', 'world.count_run_event("fossil_"+key)', 'world.count_run_event("fossil_wrong")'),
]
env = os.environ.copy()
env['XDG_DATA_HOME'] = str(ROOT / '.tmp/c24-fossils-user')
env['XDG_CACHE_HOME'] = str(ROOT / '.tmp/c24-cache')
env['C24_FOSSILS_SCRIPT'] = 'res://.tmp/c24_fossils_mutant.gd'
missed = []
try:
    for name, old, new in cases:
        assert source.count(old) == 1, (name, source.count(old))
        MUTANT.write_text(source.replace('class_name Fossils\n','').replace(old,new))
        result = subprocess.run([str(GODOT), '--headless', '--path', str(ROOT), '--script', 'res://Test/c24_fossils.gd'], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        output = result.stdout.decode(errors='replace')
        (LOGDIR / f'c24_fossils_mutation_{name}.log').write_text(output)
        caught = result.returncode == 1 and 'FAIL ' in output and 'C24 FOSSILS SUMMARY' in output and 'SCRIPT ERROR' not in output
        print(f'{name}: {"CAUGHT" if caught else "MISSED"} rc={result.returncode}')
        if not caught: missed.append(name)
finally:
    MUTANT.unlink(missing_ok=True)
print(f'C24 FOSSIL MUTATIONS cases={len(cases)} missed={len(missed)}')
raise SystemExit(bool(missed))
