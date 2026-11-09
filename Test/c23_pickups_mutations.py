#!/usr/bin/env python3
"""Run runtime pickup checks against isolated source mutations, leaving game code intact."""
import os
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
source = (root / 'scripts/pickups.gd').read_text()
cases = {
    'heal': ('p.max_hp*0.25', 'p.max_hp*0.5'),
    'bomb': ('e.max_hp*0.08', 'e.max_hp*0.04'),
    'repel': ('40.0*r', '20.0*r'),
    'thunder': ('4.0*p.powerup_mult', '2.0*p.powerup_mult'),
    'magnet': ('magnet_all = 4.0*p.powerup_mult', 'magnet_all = 2.0*p.powerup_mult'),
    'expiry': ('return 60.0 if kind == 2', 'return 600.0 if kind == 2'),
    'gold': ('gold_frac += 0.2*p.gold_mult', 'gold_frac += 0.1*p.gold_mult'),
    'motion': ('16.0+float(e.age)*6.0', '0.0'),
    'merge': ('entries[nearest].value += value', 'entries[nearest].value += 0.0'),
}
env = dict(os.environ, XDG_DATA_HOME=str(root/'.tmp/godot-data'), XDG_CACHE_HOME=str(root/'.tmp/godot-cache'))
godot = str(Path('/home/hatch/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64'))
if not Path(godot).exists():
    godot = str(Path.home()/'workspace/tools/godot/Godot_v4.3-stable_linux.x86_64')
failed = 0
for name, (old, new) in cases.items():
    assert old in source, (name, old)
    path = root/'.tmp'/f'c23_pickups_mutant_{name}.gd'
    path.write_text(source.replace(old, new))
    env['C23_PICKUPS_SCRIPT'] = 'res://.tmp/' + path.name
    result = subprocess.run([godot, '--headless', '--path', str(root), '--script', 'res://Test/c23_pickups.gd'], env=env, capture_output=True, text=True, timeout=90)
    (root/'Test/out'/f'c23b_pickups_mutant_{name}.log').write_text(result.stdout+result.stderr)
    caught = result.returncode == 1 and 'FAIL ' in result.stdout and 'SCRIPT ERROR' not in result.stderr
    print(f'{name}: caught={caught} rc={result.returncode}', flush=True)
    failed += not caught
    path.unlink()
print(f'PICKUPS MUTATIONS cases={len(cases)} missed={failed}')
raise SystemExit(int(bool(failed)))
