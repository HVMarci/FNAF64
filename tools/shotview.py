#!/usr/bin/env python3
"""shotview.py out.png in1.png [in2.png ...] [--crop x,y,w,h] [--zoom N]
Crops the 320x200 display area (VICE screenshot is 384x272) and tiles the shots."""
import sys
from PIL import Image, ImageDraw
args = sys.argv[1:]
out = args.pop(0)
crop = None; zoom = 1; cols = 2; files = []
i = 0
while i < len(args):
    if args[i] == "--crop": crop = tuple(int(v) for v in args[i+1].split(",")); i += 2
    elif args[i] == "--zoom": zoom = int(args[i+1]); i += 2
    elif args[i] == "--cols": cols = int(args[i+1]); i += 2
    else: files.append(args[i]); i += 1
tiles = []
for f in files:
    im = Image.open(f).convert("RGB")
    im = im.crop((32, 36, 32 + 320, 36 + 200))
    if crop: im = im.crop((crop[0], crop[1], crop[0] + crop[2], crop[1] + crop[3]))
    if zoom > 1: im = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
    tiles.append((f.split("/")[-1], im))
w, h = tiles[0][1].size
rows = (len(tiles) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w, rows * (h + 12)), "white")
d = ImageDraw.Draw(sheet)
for k, (n, im) in enumerate(tiles):
    x, y = (k % cols) * w, (k // cols) * (h + 12)
    sheet.paste(im, (x, y + 12)); d.text((x + 2, y), n, fill="black")
sheet.save(out)
