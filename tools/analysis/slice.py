import sys, re
B = open('/home/hatch/workspace/pokebonk-rea/scripts_out/files/origins/3be62a71e6b7643af0182c742f1dbf8e5693334fcb4fae70524563ae5a92cece/assets/main-CkI7dQhz-mvml8e65.js', encoding='utf8', errors='replace').read()
def show(term, before=300, after=500, maxn=3):
    print(f"===== {term!r} =====")
    n = 0
    for m in re.finditer(re.escape(term), B):
        s = max(0, m.start()-before); e = min(len(B), m.end()+after)
        print(B[s:e].replace('\n',' '))
        print('-----')
        n += 1
        if n >= maxn: break
    if n == 0: print('(not found)')
if __name__ == '__main__':
    term = sys.argv[1]
    b = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    a = int(sys.argv[3]) if len(sys.argv) > 3 else 500
    show(term, b, a)
