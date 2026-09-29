"""Shared layout constants (sprite positions in screen pixels, 0,0 = top-left of 320x200 area)."""
# button sprites: (x, y)
LBTN_DOOR = (45, 58)
LBTN_LIGHT = (45, 86)
RBTN_DOOR = (250, 58)
RBTN_LIGHT = (250, 86)
REC_POS = (270, 6)

def OFFICE_SPRITES_PREVIEW(imgs):
    return [
        (LBTN_DOOR[0], LBTN_DOOR[1], 0, 15), (LBTN_LIGHT[0], LBTN_LIGHT[1], 5, 7),
        (RBTN_DOOR[0], RBTN_DOOR[1], 6, 2), (RBTN_LIGHT[0], RBTN_LIGHT[1], 3, 15),
    ]
