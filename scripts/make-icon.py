#!/usr/bin/env python3
import math
import os
import subprocess

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(ROOT, "Assets")
os.makedirs(ASSETS, exist_ok=True)

SIZE = 1024
PPM = os.path.join(ASSETS, "TokenIslandIcon.ppm")
PNG = os.path.join(ASSETS, "TokenIslandIcon.png")
ICNS = os.path.join(ASSETS, "TokenIsland.icns")
ICONSET = os.path.join(ASSETS, "TokenIsland.iconset")


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def blend(dst, src, alpha):
    return tuple(int(dst[i] * (1 - alpha) + src[i] * alpha) for i in range(3))


def rounded_rect_alpha(x, y, left, top, right, bottom, radius):
    px = min(max(x, left + radius), right - radius)
    py = min(max(y, top + radius), bottom - radius)
    distance = math.hypot(x - px, y - py)
    if left + radius <= x <= right - radius or top + radius <= y <= bottom - radius:
        return 1.0 if left <= x <= right and top <= y <= bottom else 0.0
    if distance <= radius - 1:
        return 1.0
    if distance <= radius + 1:
        return max(0.0, min(1.0, radius + 1 - distance))
    return 0.0


def distance_to_segment(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    length2 = vx * vx + vy * vy
    if length2 == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / length2))
    cx, cy = ax + t * vx, ay + t * vy
    return math.hypot(px - cx, py - cy)


def cubic(p0, p1, p2, p3, t):
    u = 1 - t
    x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
    y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
    return x, y


curve_points = []
segments = [
    ((205, 660), (292, 656), (314, 556), (382, 552)),
    ((382, 552), (455, 548), (438, 684), (508, 676)),
    ((508, 676), (597, 666), (565, 370), (663, 363)),
    ((663, 363), (740, 358), (762, 478), (819, 472)),
]
for segment in segments:
    for i in range(80):
        curve_points.append(cubic(*segment, i / 79))

pixels = bytearray()
for y in range(SIZE):
    for x in range(SIZE):
        bg_alpha = rounded_rect_alpha(x, y, 92, 92, 932, 932, 196)
        if bg_alpha <= 0:
            color = (0, 0, 0)
        else:
            t = (x + y) / (SIZE * 2)
            color = mix((23, 48, 66), (13, 23, 32), min(t * 1.5, 1))
            color = blend(color, (18, 44, 51), max(0, t - 0.55) * 0.9)
            glass_alpha = rounded_rect_alpha(x, y, 114, 114, 910, 910, 174)
            if glass_alpha:
                color = blend(color, (255, 255, 255), 0.055 * glass_alpha)
            for gy in (320, 452, 584):
                if 214 <= x <= 810 and abs(y - gy) <= 5:
                    color = blend(color, (255, 255, 255), 0.10)
            min_distance = 10_000
            for a, b in zip(curve_points, curve_points[1:]):
                min_distance = min(min_distance, distance_to_segment(x, y, a[0], a[1], b[0], b[1]))
            if min_distance < 44:
                glow = max(0, 1 - min_distance / 44)
                color = blend(color, (69, 217, 194), 0.20 * glow)
            if min_distance < 29:
                line_alpha = max(0, 1 - min_distance / 29)
                color = blend(color, (74, 230, 168), min(1, 0.92 + 0.08 * line_alpha))
            for cx, cy, r, col in [(663, 363, 42, (116, 246, 211)), (819, 472, 28, (116, 246, 211))]:
                d = math.hypot(x - cx, y - cy)
                if d <= r:
                    color = blend(color, col, 0.98)
            for x1, x2, yy in [(254, 398, 292), (254, 476, 366)]:
                if x1 <= x <= x2 and abs(y - yy) <= 20:
                    color = blend(color, (255, 255, 255), 0.86)
        pixels.extend(color)

with open(PPM, "wb") as f:
    f.write(f"P6\n{SIZE} {SIZE}\n255\n".encode())
    f.write(pixels)

subprocess.run(["sips", "-s", "format", "png", PPM, "--out", PNG], check=True, stdout=subprocess.DEVNULL)

subprocess.run(["rm", "-rf", ICONSET], check=True)
os.makedirs(ICONSET, exist_ok=True)
specs = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]
for size, name in specs:
    subprocess.run(
        ["sips", "-z", str(size), str(size), PNG, "--out", os.path.join(ICONSET, name)],
        check=True,
        stdout=subprocess.DEVNULL,
    )
subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", ICNS], check=True)

# Clean up intermediates
for f in (PPM, PNG):
    if os.path.exists(f):
        os.remove(f)

print(ICNS)
