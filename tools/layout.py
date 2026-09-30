"""Shared layout constants (sprite positions in screen pixels, 0,0 = top-left of 320x200 area)."""
# button sprites: (x, y)
LBTN_DOOR = (66, 58)
LBTN_LIGHT = (66, 86)
RBTN_DOOR = (231, 58)
RBTN_LIGHT = (231, 86)
REC_POS = (270, 6)

def OFFICE_SPRITES_PREVIEW(imgs):
    return [
        (LBTN_DOOR[0], LBTN_DOOR[1], 0, 15), (LBTN_LIGHT[0], LBTN_LIGHT[1], 5, 7),
        (RBTN_DOOR[0], RBTN_DOOR[1], 6, 2), (RBTN_LIGHT[0], RBTN_LIGHT[1], 3, 15),
    ]


# ------------------------------------------------------------------ memory layout (shared by check_layout.py, memmap.py)
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = os.path.join(ROOT, "build")

# Fixed RAM areas the program builds at run time (name, start, end exclusive).
FIXED = [
    ("zero page vars", 0x0010, 0x0070),
    ("stack + Sparkle resident + loader buffer", 0x0100, 0x0400),
    ("RAM tables + sound vars", 0x0c00, 0x0d00),
    ("font copy", 0x0d00, 0x0f00),
    ("game variables", 0x0f00, 0x1000),
    ("save page", 0xbd00, 0xbe00),
    ("noise screen 0", 0xc000, 0xc400),
    ("noise screen 1", 0xc400, 0xc800),
    ("dark bar screen", 0xcc00, 0xd000),
    ("noise screen 2", 0xd000, 0xd400),
    ("noise screen 3", 0xd400, 0xd800),
    ("white bar screen", 0xd800, 0xdc00),
    ("grey bar screen", 0xdc00, 0xe000),
    ("noise bitmap (bank 3)", 0xe000, 0x10000),
]
CODE_FILES = ("code1.prg", "code2.prg", "code3.prg", "code4.prg")
TRANSIENT_BUNDLES = ("camera", "title", "jumpscare", "newspaper", "phone")


def prg(path):
    d = open(path, "rb").read()
    a = d[0] | d[1] << 8
    return a, a + len(d) - 2


def collect(sls_name=None):
    """-> (persistent, transient): persistent = [(name, start, end)], transient = [(bundle, name, start, end)].
    Persistent = code, office assets, patches, sprites and the fixed RAM areas. The title screen, camera,
    jumpscare, newspaper and phone bundles share the camera buffer on purpose but must not touch anything persistent."""
    persistent = list(FIXED)
    for c in CODE_FILES:
        a, e = prg(os.path.join(B, c))
        persistent.append((c, a, e))
    transient = []
    bundle = "?"
    if sls_name:
        sls_path = os.path.join(B, sls_name + ".sls")
    else:
        sls_path = sorted((os.path.join(B, f) for f in os.listdir(B) if f.endswith(".sls")), key=os.path.getmtime)[-1]
    for line in open(sls_path).read().splitlines():
        m = re.match(r"<< (.*) >>", line)
        if m: bundle = m.group(1)
        m = re.match(r'File:\t"([^"]+)"\t([0-9a-f]+)', line)
        if m:
            if "dark" in bundle: continue        # replaces the office picture on purpose
            n = os.path.getsize(os.path.join(B, m.group(1)))
            a = int(m.group(2), 16)
            if any(k in bundle for k in TRANSIENT_BUNDLES):
                transient.append((bundle, m.group(1), a, a + n))
            else:
                persistent.append((m.group(1), a, a + n))
    return persistent, transient
