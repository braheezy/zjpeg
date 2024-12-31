const std = @import("std");
const image = @import("image.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const jpeg = @import("jpeg/decoder.zig");
pub const Decoder = jpeg.Decoder;

const print = std.debug.print;

const helpText =
    \\Usage: zjpeg [options]] <jpeg file>
    \\Options:
    \\  -h, --help  Display this help message
    \\  -c, --config-only  Decode and print the image configuration
;

pub fn main() !void {
    // Memory allocation setup
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) {
        std.process.exit(1);
    };

    const stdout = std.io.getStdOut().writer();

    // Read arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        // no args, exit
        std.log.err("Missing input file\n", .{});
        // EX_USAGE: command line usage error
        std.process.exit(64);
    }
    // var isConfigOnlyFlag: bool = false;

    // handle CLI arguments
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try stdout.print(helpText, .{});
            std.process.exit(0);
            // } else if (std.mem.eql(u8, arg, "--config-only") or std.mem.eql(u8, arg, "-c")) {
            //     isConfigOnlyFlag = true;
        } else {
            // assume input file
            const jpeg_file = std.fs.cwd().openFile(arg, .{}) catch |err| {
                std.log.err("Failed to open jpeg file {s}: {any}", .{ arg, err });
                // EX_NOINPUT: cannot open input
                std.process.exit(66);
            };
            defer jpeg_file.close();

            var bufferedReader = std.io.bufferedReader(jpeg_file.reader());
            const reader = bufferedReader.reader().any();

            // if (isConfigOnlyFlag) {
            //     const img_config = try jpeg.decodeConfig(reader);
            //     print("Image config: {any}\n", .{img_config});
            //     std.process.exit(0);
            // }

            const img = jpeg.decode(allocator, reader) catch |err| {
                std.log.err("Failed to decode jpeg file: {any}", .{err});
                return err;
            };
            defer img.free(allocator);

            switch (img) {
                .YCbCr => |i| {
                    try draw(allocator, arg, i);
                },
                else => return error.NotReadyYet,
            }
        }
    }
}

fn draw(al: std.mem.Allocator, file_name: []const u8, img: image.YCbCrImage) !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        std.debug.print("Failed to initialize SDL: {s}\n", .{sdl.SDL_GetError()});
        return;
    }
    defer sdl.SDL_Quit();

    const width = img.bounds().dX();
    const height = img.bounds().dY();
    const scale_factor = 4;

    const window_title = try std.fmt.allocPrintZ(al, "zjpeg view - {s}", .{file_name});
    defer al.free(window_title);

    const window = sdl.SDL_CreateWindow(
        window_title,
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        @intCast(@divTrunc(width, scale_factor)),
        @intCast(@divTrunc(height, scale_factor)),
        sdl.SDL_WINDOW_SHOWN,
    );
    if (window == null) {
        std.debug.print("Failed to create window: {s}\n", .{sdl.SDL_GetError()});
        return;
    }
    defer sdl.SDL_DestroyWindow(window);

    const renderer = sdl.SDL_CreateRenderer(
        window,
        -1,
        sdl.SDL_RENDERER_ACCELERATED | sdl.SDL_RENDERER_PRESENTVSYNC,
    );
    if (renderer == null) {
        std.debug.print("Failed to create renderer: {s}\n", .{sdl.SDL_GetError()});
        return;
    }
    defer sdl.SDL_DestroyRenderer(renderer);

    const texture = sdl.SDL_CreateTexture(
        renderer,
        sdl.SDL_PIXELFORMAT_RGBA32,
        sdl.SDL_TEXTUREACCESS_STREAMING,
        @intCast(width),
        @intCast(height),
    );
    if (texture == null) {
        std.debug.print("Failed to create texture: {s}\n", .{sdl.SDL_GetError()});
        return;
    }
    defer sdl.SDL_DestroyTexture(texture);

    var tex_pixels: ?*anyopaque = null;
    var pitch: i32 = 0;
    if (sdl.SDL_LockTexture(texture, null, &tex_pixels, &pitch) != 0) {
        std.debug.print("Failed to lock texture: {s}\n", .{sdl.SDL_GetError()});
        return;
    }

    const tex_data: [*]u8 = @ptrCast(tex_pixels);
    const row_length = @as(usize, @intCast(pitch));
    // RGBA is 4 bytes per pixel
    const pixel_stride = 4;

    var y = img.bounds().min.y;
    while (y < img.bounds().max.y) : (y += 1) {
        var x = img.bounds().min.x;
        while (x < img.bounds().max.x) : (x += 1) {
            var color = img.YCbCrAt(x, y);
            const r, const g, const b, const a = color.toRGBA();

            const row_offset = @as(usize, @intCast(y - img.bounds().min.y)) * row_length;
            const col_offset = @as(usize, @intCast(x - img.bounds().min.x)) * pixel_stride;
            const dst_index = row_offset + col_offset;

            tex_data[dst_index + 0] = r;
            tex_data[dst_index + 1] = g;
            tex_data[dst_index + 2] = b;
            tex_data[dst_index + 3] = a;
        }
    }

    sdl.SDL_UnlockTexture(texture);

    var event: sdl.SDL_Event = undefined;
    var running = true;
    while (running) {
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.SDL_QUIT => running = false,
                else => {},
            }
        }

        _ = sdl.SDL_RenderClear(renderer);
        _ = sdl.SDL_RenderCopy(renderer, texture, null, null);
        sdl.SDL_RenderPresent(renderer);
    }
}
