// draw.zig
const std = @import("std");
const image = @import("image.zig");
const color = @import("color.zig");
const geom = @import("geometry.zig");
const Point = geom.Point;
const Rectangle = geom.Rectangle;

pub const DrawOp = enum {
    Source, // Simply copy source over destination
    Over, // Alpha compositing
};

/// Draws src image onto dst image with the specified drawing operation
// pub fn Draw(
//     dst: *image.Image,
//     dst_rect: Rectangle,
//     src: image.Image,
//     src_point: Point,
//     op: DrawOp,
// ) void {
//     // Implementation will handle different image type combinations
//     switch (dst.*) {
//         .RGBA => |*rgba_dst| {
//             drawToRGBA(rgba_dst, dst_rect, src, src_point, op);
//         },
//         // Add other cases for different image types
//         else => {
//             // Convert to RGBA and draw
//         },
//     }
// }

/// Basic primitive drawing functions
pub const Drawer = struct {
    img: *image.Image,

    pub fn init(img: *image.Image) Drawer {
        return .{
            .img = img,
        };
    }

    /// Fill the entire image with the specified color
    pub fn clear(self: *Drawer, c: color.Color) void {
        switch (self.img.*) {
            .RGBA => |*rgba| {
                const rgba_color = c.toRGBA();

                // Pre-calculate 8-bit color components
                const r: u8 = @intCast(rgba_color[0] >> 8);
                const g: u8 = @intCast(rgba_color[1] >> 8);
                const b: u8 = @intCast(rgba_color[2] >> 8);
                const a: u8 = @intCast(rgba_color[3] >> 8);

                // Fill all pixels with the color
                var i: usize = 0;
                while (i < rgba.pixels.len) : (i += 4) {
                    rgba.pixels[i + 0] = r;
                    rgba.pixels[i + 1] = g;
                    rgba.pixels[i + 2] = b;
                    rgba.pixels[i + 3] = a;
                }
            },
            // Add other image type cases as needed
            else => {
                // Fallback implementation using setPixel for other image types
                const bounds = self.img.bounds();
                var y = bounds.min.y;
                while (y < bounds.max.y) : (y += 1) {
                    var x = bounds.min.x;
                    while (x < bounds.max.x) : (x += 1) {
                        self.setPixel(x, y, c);
                    }
                }
            },
        }
    }

    /// Set a single pixel
    pub fn setPixel(self: *Drawer, x: i32, y: i32, c: color.Color) void {
        switch (self.img.*) {
            .RGBA => |*rgba| {
                const point = Point{ .x = x, .y = y };
                if (!point.In(rgba.bounds())) return;
                const i = rgba.pixOffset(x, y);
                const rgba_color = c.toRGBA();
                rgba.pixels[@intCast(i + 0)] = @intCast(rgba_color[0] >> 8);
                rgba.pixels[@intCast(i + 1)] = @intCast(rgba_color[1] >> 8);
                rgba.pixels[@intCast(i + 2)] = @intCast(rgba_color[2] >> 8);
                rgba.pixels[@intCast(i + 3)] = @intCast(rgba_color[3] >> 8);
            },
            // Add other image type cases
            else => {},
        }
    }

    /// Draw a line using Bresenham's algorithm
    pub fn drawLine(self: *Drawer, x0: i32, y0: i32, x1: i32, y1: i32, c: color.Color) void {
        const dx = @abs(x1 - x0);
        const dy = -@abs(y1 - y0);
        const sx: i32 = if (x0 < x1) 1 else -1;
        const sy: i32 = if (y0 < y1) 1 else -1;
        const err = dx + dy;

        const x = x0;
        const y = y0;

        while (true) {
            self.setPixel(x, y, c);
            if (x == x1 and y == y1) break;
            const e2 = 2 * err;
            if (e2 >= dy) {
                if (x == x1) break;
                err += dy;
                x += sx;
            }
            if (e2 <= dx) {
                if (y == y1) break;
                err += dx;
                y += sy;
            }
        }
    }

    /// Draw a filled rectangle
    pub fn fillRect(self: *Drawer, rect: Rectangle, c: color.Color) void {
        var y = rect.min.y;
        while (y < rect.max.y) : (y += 1) {
            var x = rect.min.x;
            while (x < rect.max.x) : (x += 1) {
                self.setPixel(x, y, c);
            }
        }
    }

    /// Draw a circle using Bresenham's algorithm
    pub fn drawCircle(self: *Drawer, x0: i32, y0: i32, radius: i32, c: color.Color) void {
        var x: i32 = radius;
        var y: i32 = 0;
        var err: i32 = 0;

        while (x >= y) {
            self.setPixel(x0 + x, y0 + y, c);
            self.setPixel(x0 + y, y0 + x, c);
            self.setPixel(x0 - y, y0 + x, c);
            self.setPixel(x0 - x, y0 + y, c);
            self.setPixel(x0 - x, y0 - y, c);
            self.setPixel(x0 - y, y0 - x, c);
            self.setPixel(x0 + y, y0 - x, c);
            self.setPixel(x0 + x, y0 - y, c);

            y += 1;
            err += 1 + 2 * y;
            if (2 * (err - x) + 1 > 0) {
                x -= 1;
                err += 1 - 2 * x;
            }
        }
    }
};
