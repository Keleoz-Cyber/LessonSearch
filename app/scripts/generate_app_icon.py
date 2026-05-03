from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import math

OUT = Path("app/assets")
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 1024

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0,2,4))

def rounded_shadow(base, bbox, radius, shadow_offset=(0,28), shadow_blur=36, shadow_color=(41, 74, 120, 65)):
    shadow = Image.new("RGBA", base.size, (0,0,0,0))
    sd = ImageDraw.Draw(shadow)
    x1,y1,x2,y2 = bbox
    ox,oy = shadow_offset
    sd.rounded_rectangle((x1+ox,y1+oy,x2+ox,y2+oy), radius=radius, fill=shadow_color)
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur))
    base.alpha_composite(shadow)

def create_background():
    img = Image.new("RGBA", (SIZE, SIZE), (255,255,255,255))
    pix = img.load()
    c1 = hex_to_rgb("#F1F8FF")
    c2 = hex_to_rgb("#DCEEFF")
    c3 = hex_to_rgb("#CFE3FF")
    center = (SIZE*0.35, SIZE*0.22)
    maxd = math.sqrt((SIZE)**2 + (SIZE)**2)
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x*0.55 + y*0.75) / (SIZE*1.3)
            dx = x-center[0]; dy = y-center[1]
            r = min(1, math.sqrt(dx*dx+dy*dy)/(maxd*0.72))
            a = min(1, max(0, t*0.65 + r*0.35))
            if a < 0.65:
                p = a/0.65
                col = tuple(int(c1[i]*(1-p)+c2[i]*p) for i in range(3))
            else:
                p = (a-0.65)/0.35
                col = tuple(int(c2[i]*(1-p)+c3[i]*p) for i in range(3))
            pix[x,y] = (*col, 255)
    draw = ImageDraw.Draw(img)
    draw.ellipse((-120, -90, 280, 310), fill=(91, 158, 232, 34))
    draw.ellipse((760, -80, 1110, 270), fill=(76, 175, 110, 28))
    draw.ellipse((760, 740, 1120, 1100), fill=(50, 111, 166, 24))
    return img

def round_line(draw, xy, fill, width):
    draw.line(xy, fill=fill, width=width, joint="curve")
    r = width // 2
    for x, y in [xy[0], xy[-1]]:
        draw.ellipse((x-r, y-r, x+r, y+r), fill=fill)

def create_foreground(with_shadow=True):
    img = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    if with_shadow:
        sh = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
        sd = ImageDraw.Draw(sh)
        sd.ellipse((248, 220, 635, 607), outline=(20, 58, 100, 70), width=58)
        round_line(sd, [(560, 552), (690, 682)], fill=(20, 58, 100, 70), width=66)
        sh = sh.filter(ImageFilter.GaussianBlur(18))
        img.alpha_composite(sh)
    blue = (48, 109, 166, 255)
    draw.ellipse((248, 220, 635, 607), outline=blue, width=58)
    round_line(draw, [(560, 552), (690, 682)], fill=blue, width=66)

    card = (310, 272, 735, 712)
    if with_shadow:
        rounded_shadow(img, card, radius=78, shadow_offset=(0,26), shadow_blur=30, shadow_color=(34, 79, 132, 78))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(card, radius=78, fill=(255,255,255,255))
    draw.rounded_rectangle(card, radius=78, outline=(211, 231, 250, 255), width=5)
    draw.pieslice((640, 272, 830, 462), 180, 270, fill=(231, 244, 255, 255))
    draw.line([(646, 342), (728, 342)], fill=(202, 226, 248, 255), width=5)

    list_blue = (54, 142, 222, 255)
    muted = (159, 184, 209, 255)
    for i, yy in enumerate([405, 492, 579]):
        draw.ellipse((374, yy-16, 406, yy+16), fill=list_blue if i < 2 else (158, 210, 250, 255))
        draw.rounded_rectangle((430, yy-14, 606, yy+14), radius=14, fill=muted if i != 1 else (130, 170, 207, 255))
        draw.rounded_rectangle((430, yy+26, 555, yy+42), radius=8, fill=(217, 231, 244, 255))

    green = (74, 190, 105, 255)
    green_dark = (46, 158, 82, 255)
    if with_shadow:
        sh = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
        sd = ImageDraw.Draw(sh)
        sd.ellipse((500, 548, 754, 802), fill=(30, 100, 60, 78))
        sh = sh.filter(ImageFilter.GaussianBlur(24))
        img.alpha_composite(sh)
        draw = ImageDraw.Draw(img)
    draw.ellipse((500, 548, 754, 802), fill=green)
    draw.ellipse((500, 548, 754, 802), outline=green_dark, width=5)
    round_line(draw, [(568, 672), (622, 724), (702, 616)], fill=(255,255,255,255), width=48)
    return img

bg = create_background()
fg = create_foreground(with_shadow=True)
icon = bg.copy()
icon.alpha_composite(fg)
icon_rgb = Image.new("RGB", (SIZE, SIZE), (255,255,255))
icon_rgb.paste(icon, mask=icon.split()[-1])
icon_rgb.save(OUT / "icon.png", "PNG", optimize=True)
fg.save(OUT / "icon_foreground.png", "PNG", optimize=True)
print("Generated app/assets/icon.png and app/assets/icon_foreground.png")
