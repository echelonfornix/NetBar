#!/usr/bin/env python3
import math
import os
import struct
import subprocess
import zlib


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ICONSET = os.path.join(ROOT, "Resources", "AppIcon.iconset")
ICNS = os.path.join(ROOT, "Resources", "AppIcon.icns")


def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def write_png(path, width, height, pixels):
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            row.extend(pixels[y * width + x])
        rows.append(bytes(row))

    payload = b"".join(rows)
    data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(payload, 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as handle:
        handle.write(data)


def smoothstep(edge0, edge1, value):
    if edge0 == edge1:
        return 1.0 if value >= edge1 else 0.0
    x = min(1.0, max(0.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def rounded_rect_alpha(x, y, size, radius):
    cx = min(max(x, radius), size - radius)
    cy = min(max(y, radius), size - radius)
    dist = math.hypot(x - cx, y - cy)
    return 1.0 - smoothstep(radius - 1.5, radius + 1.5, dist)


def blend(base, overlay):
    br, bg, bb, ba = base
    or_, og, ob, oa = overlay
    alpha = oa / 255.0
    inv = 1.0 - alpha
    return (
        int(or_ * alpha + br * inv),
        int(og * alpha + bg * inv),
        int(ob * alpha + bb * inv),
        int(255 * (alpha + ba / 255.0 * inv)),
    )


def draw_line(pixels, size, a, b, color, width):
    ax, ay = a
    bx, by = b
    dx = bx - ax
    dy = by - ay
    length_sq = dx * dx + dy * dy
    for y in range(size):
        for x in range(size):
            if length_sq == 0:
                distance = math.hypot(x - ax, y - ay)
            else:
                t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / length_sq))
                px = ax + t * dx
                py = ay + t * dy
                distance = math.hypot(x - px, y - py)
            alpha = int(255 * (1.0 - smoothstep(width - 1.2, width + 1.2, distance)))
            if alpha > 0:
                idx = y * size + x
                pixels[idx] = blend(pixels[idx], (*color[:3], min(alpha, color[3])))


def draw_circle(pixels, size, center, radius, color):
    cx, cy = center
    for y in range(size):
        for x in range(size):
            distance = math.hypot(x - cx, y - cy)
            alpha = int(color[3] * (1.0 - smoothstep(radius - 1.2, radius + 1.2, distance)))
            if alpha > 0:
                idx = y * size + x
                pixels[idx] = blend(pixels[idx], (*color[:3], alpha))


def make_icon(size, path):
    pixels = []
    radius = size * 0.22
    for y in range(size):
        for x in range(size):
            alpha = int(255 * rounded_rect_alpha(x, y, size - 1, radius))
            top = y / max(1, size - 1)
            r = int(24 + 20 * top)
            g = int(92 + 70 * (1.0 - top))
            b = int(120 + 60 * (1.0 - top))
            pixels.append((r, g, b, alpha))

    nodes = [
        (size * 0.31, size * 0.34),
        (size * 0.68, size * 0.31),
        (size * 0.50, size * 0.66),
        (size * 0.30, size * 0.72),
        (size * 0.73, size * 0.68),
    ]

    line_color = (229, 245, 242, 190)
    draw_line(pixels, size, nodes[0], nodes[1], line_color, size * 0.018)
    draw_line(pixels, size, nodes[0], nodes[2], line_color, size * 0.018)
    draw_line(pixels, size, nodes[1], nodes[2], line_color, size * 0.018)
    draw_line(pixels, size, nodes[2], nodes[3], line_color, size * 0.018)
    draw_line(pixels, size, nodes[2], nodes[4], line_color, size * 0.018)

    for index, node in enumerate(nodes):
        outer = (255, 255, 255, 210)
        inner = (97, 218, 183, 255) if index == 2 else (238, 247, 245, 255)
        draw_circle(pixels, size, node, size * 0.065, outer)
        draw_circle(pixels, size, node, size * 0.038, inner)

    write_png(path, size, size, pixels)


def main():
    os.makedirs(ICONSET, exist_ok=True)
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for filename, size in sizes:
        make_icon(size, os.path.join(ICONSET, filename))

    subprocess.run(["/usr/bin/iconutil", "-c", "icns", ICONSET, "-o", ICNS], check=True)
    print(f"Created {ICNS}")


if __name__ == "__main__":
    main()
