from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from AppKit import NSBitmapImageRep, NSImage, NSPNGFileType


@dataclass(frozen=True)
class SegmentSpec:
    name: str
    start_ratio: float
    end_ratio: float
    padding_x: int = 12
    padding_y: int = 12
    body_core_only: bool = False
    max_core_height_ratio: float | None = None
    feather_left: int = 0
    feather_right: int = 0


SEGMENTS = [
    # The tail owns the full fin silhouette. Rear/peduncle are body-core-only to
    # avoid duplicating caudal fin geometry in multiple slices.
    SegmentSpec("fish_tail", 0.00, 0.28, 10, 10, feather_right=8),
    SegmentSpec("fish_peduncle", 0.22, 0.36, 12, 10, body_core_only=True, max_core_height_ratio=0.16, feather_right=12),
    SegmentSpec("fish_rear", 0.34, 0.50, 14, 10, body_core_only=True, max_core_height_ratio=0.26, feather_left=12),
    SegmentSpec("fish_mid", 0.44, 0.62, 16, 18, feather_left=14),
    SegmentSpec("fish_shoulder", 0.50, 0.78, 18, 20, feather_left=14),
    SegmentSpec("fish_head", 0.71, 1.00, 20, 20, feather_left=18),
]


def load_bitmap(path: Path) -> NSBitmapImageRep:
    image = NSImage.alloc().initWithContentsOfFile_(str(path))
    if image is None:
        raise RuntimeError(f"Failed to load image: {path}")
    rep = NSBitmapImageRep.alloc().initWithData_(image.TIFFRepresentation())
    if rep is None:
        raise RuntimeError(f"Failed to create bitmap rep: {path}")
    return rep


def corner_background(rep: NSBitmapImageRep) -> tuple[float, float, float]:
    width = rep.pixelsWide()
    height = rep.pixelsHigh()
    samples = []
    for x, y in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]:
        color = rep.colorAtX_y_(x, y)
        samples.append((color.redComponent(), color.greenComponent(), color.blueComponent()))
    return tuple(sum(s[i] for s in samples) / len(samples) for i in range(3))


def alpha_from_background(
    rep: NSBitmapImageRep,
    background: tuple[float, float, float],
    threshold: float = 0.09,
) -> tuple[list[list[tuple[int, int, int, int]]], tuple[int, int, int, int]]:
    width = rep.pixelsWide()
    height = rep.pixelsHigh()
    pixels: list[list[tuple[int, int, int, int]]] = []

    min_x, min_y = width, height
    max_x = max_y = -1

    for y in range(height):
        row = []
        for x in range(width):
            color = rep.colorAtX_y_(x, y)
            red = color.redComponent()
            green = color.greenComponent()
            blue = color.blueComponent()

            distance = abs(red - background[0]) + abs(green - background[1]) + abs(blue - background[2])
            alpha = 0 if distance < threshold else 255

            if alpha:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

            row.append(
                (
                    int(red * 255),
                    int(green * 255),
                    int(blue * 255),
                    alpha,
                )
            )
        pixels.append(row)

    if max_x < min_x or max_y < min_y:
        raise RuntimeError("No foreground detected in source image.")

    return pixels, (min_x, min_y, max_x, max_y)


def crop_pixels(
    pixels: list[list[tuple[int, int, int, int]]],
    rect: tuple[int, int, int, int],
) -> list[list[tuple[int, int, int, int]]]:
    min_x, min_y, max_x, max_y = rect
    return [row[min_x : max_x + 1] for row in pixels[min_y : max_y + 1]]


def global_body_center_y(pixels: list[list[tuple[int, int, int, int]]]) -> int:
    weighted_sum = 0
    weight_count = 0

    for y, row in enumerate(pixels):
        row_weight = sum(1 for pixel in row if pixel[3] > 0)
        if row_weight == 0:
            continue
        weighted_sum += y * row_weight
        weight_count += row_weight

    if weight_count == 0:
        raise RuntimeError("Cannot infer body center from empty image.")

    return int(round(weighted_sum / weight_count))


def body_core_bounds_for_column(
    pixels: list[list[tuple[int, int, int, int]]],
    column_x: int,
    center_y: int,
) -> tuple[int, int] | None:
    occupied = [y for y in range(len(pixels)) if pixels[y][column_x][3] > 0]
    if not occupied:
        return None

    intervals: list[tuple[int, int]] = []
    start = occupied[0]
    end = occupied[0]

    for y in occupied[1:]:
        if y == end + 1:
            end = y
        else:
            intervals.append((start, end))
            start = y
            end = y
    intervals.append((start, end))

    containing = [interval for interval in intervals if interval[0] <= center_y <= interval[1]]
    if containing:
        return max(containing, key=lambda interval: interval[1] - interval[0])

    return min(
        intervals,
        key=lambda interval: min(abs(center_y - interval[0]), abs(center_y - interval[1]))
    )


def extract_body_core(
    pixels: list[list[tuple[int, int, int, int]]],
    padding_y: int,
    max_core_height_ratio: float | None = None,
) -> list[list[tuple[int, int, int, int]]]:
    height = len(pixels)
    width = len(pixels[0])
    center_y = global_body_center_y(pixels)
    max_core_height = None
    if max_core_height_ratio is not None:
        max_core_height = max(8, int(round(height * max_core_height_ratio)))

    output: list[list[tuple[int, int, int, int]]] = [
        [(0, 0, 0, 0) for _ in range(width)] for _ in range(height)
    ]

    for x in range(width):
        bounds = body_core_bounds_for_column(pixels, x, center_y)
        if bounds is None:
            continue

        start_y = bounds[0]
        end_y = bounds[1]

        if max_core_height is not None and end_y - start_y + 1 > max_core_height:
            interval_center = (start_y + end_y) // 2
            half_height = max_core_height // 2
            start_y = interval_center - half_height
            end_y = start_y + max_core_height - 1

        start_y = max(0, start_y - padding_y)
        end_y = min(height - 1, end_y + padding_y)
        for y in range(start_y, end_y + 1):
            output[y][x] = pixels[y][x]

    return output


def trim_alpha_bounds(
    pixels: list[list[tuple[int, int, int, int]]],
    padding_x: int,
    padding_y: int,
) -> tuple[int, int, int, int]:
    height = len(pixels)
    width = len(pixels[0])
    min_x, min_y = width, height
    max_x = max_y = -1

    for y in range(height):
        for x in range(width):
            if pixels[y][x][3] > 0:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    if max_x < min_x or max_y < min_y:
        raise RuntimeError("Segment has no visible pixels.")

    return (
        max(0, min_x - padding_x),
        max(0, min_y - padding_y),
        min(width - 1, max_x + padding_x),
        min(height - 1, max_y + padding_y),
    )


def write_png(pixels: list[list[tuple[int, int, int, int]]], output_path: Path) -> None:
    height = len(pixels)
    width = len(pixels[0])

    rep = NSBitmapImageRep.alloc().initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bitmapFormat_bytesPerRow_bitsPerPixel_(
        None,
        width,
        height,
        8,
        4,
        True,
        False,
        "NSCalibratedRGBColorSpace",
        0,
        width * 4,
        32,
    )
    if rep is None:
        raise RuntimeError(f"Failed to allocate bitmap for {output_path}")

    bitmap = rep.bitmapData()
    for y in range(height):
        dest_y = height - 1 - y
        for x in range(width):
            offset = dest_y * width * 4 + x * 4
            r, g, b, a = pixels[y][x]
            bitmap[offset] = r
            bitmap[offset + 1] = g
            bitmap[offset + 2] = b
            bitmap[offset + 3] = a

    data = rep.representationUsingType_properties_(NSPNGFileType, None)
    data.writeToFile_atomically_(str(output_path), True)


def feather_segment_edges(
    pixels: list[list[tuple[int, int, int, int]]],
    feather_left: int,
    feather_right: int,
) -> list[list[tuple[int, int, int, int]]]:
    height = len(pixels)
    width = len(pixels[0])
    output = [[pixel for pixel in row] for row in pixels]

    for y in range(height):
        for x in range(width):
            r, g, b, a = output[y][x]
            if a == 0:
                continue

            alpha_scale = 1.0
            if feather_left > 0 and x < feather_left:
                edge_t = max(0.0, (x + 1) / feather_left)
                alpha_scale = min(alpha_scale, edge_t * edge_t)
            if feather_right > 0 and x >= width - feather_right:
                distance = width - x
                edge_t = max(0.0, distance / feather_right)
                alpha_scale = min(alpha_scale, edge_t * edge_t)

            if alpha_scale < 1.0:
                output[y][x] = (
                    int(round(r * alpha_scale)),
                    int(round(g * alpha_scale)),
                    int(round(b * alpha_scale)),
                    int(round(a * alpha_scale)),
                )

    return output


def segment_fish(source_path: Path, output_dir: Path) -> list[tuple[str, int, int]]:
    rep = load_bitmap(source_path)
    background = corner_background(rep)
    pixels, bbox = alpha_from_background(rep, background)

    cropped = crop_pixels(pixels, bbox)

    full_height = len(cropped)
    full_width = len(cropped[0])
    output_dir.mkdir(parents=True, exist_ok=True)

    results: list[tuple[str, int, int]] = []
    for spec in SEGMENTS:
        start_x = max(0, int(full_width * spec.start_ratio))
        end_x = min(full_width - 1, int(full_width * spec.end_ratio))
        if end_x <= start_x:
            raise RuntimeError(f"Invalid slice for {spec.name}")

        base_slice = crop_pixels(cropped, (start_x, 0, end_x, full_height - 1))
        if spec.body_core_only:
            base_slice = extract_body_core(
                base_slice,
                padding_y=max(8, spec.padding_y),
                max_core_height_ratio=spec.max_core_height_ratio,
            )
        bounds = trim_alpha_bounds(base_slice, spec.padding_x, spec.padding_y)
        segment_pixels = crop_pixels(base_slice, bounds)
        segment_pixels = feather_segment_edges(
            segment_pixels,
            feather_left=spec.feather_left,
            feather_right=spec.feather_right,
        )

        output_path = output_dir / f"{spec.name}.png"
        write_png(segment_pixels, output_path)
        results.append((spec.name, len(segment_pixels[0]), len(segment_pixels)))

    return results


def main() -> None:
    repo_root = Path("/Users/bigfish/Documents/Code/Goldfish")
    source_path = repo_root / "tmp" / "fish_source" / "fish_master.png"
    output_dir = repo_root / "tmp" / "fish_output" / "segments"

    results = segment_fish(source_path, output_dir)
    print(f"Source: {source_path}")
    print(f"Output: {output_dir}")
    for name, width, height in results:
        print(f"{name}: {width}x{height}")


if __name__ == "__main__":
    main()
