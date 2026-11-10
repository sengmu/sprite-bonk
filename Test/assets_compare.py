"""PIL side-by-side evidence: approved art left, live scene right."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SCREENS = {1: 'hud', 2: 'menu', 3: 'draft', 4: 'lab', 5: 'result', 6: 'wallet'}
for number, screen in SCREENS.items():
    target, = (ROOT / 'design/art-concepts/ui-approved').glob(f'U{number}_*.png')
    actual = ROOT / f'Test/out/ui_{screen}_assets_wiring.png'
    left = Image.open(target).convert('RGB')
    right = Image.open(actual).convert('RGB')
    height = right.height
    left = left.resize((round(left.width * height / left.height), height), Image.Resampling.LANCZOS)
    canvas = Image.new('RGB', (left.width + right.width, height))
    canvas.paste(left, (0, 0))
    canvas.paste(right, (left.width, 0))
    output = ROOT / f'Test/out/sbs_U{number}.png'
    canvas.save(output)
    print(output.relative_to(ROOT), canvas.size)
