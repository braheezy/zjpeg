const std = @import("std");
pub const image = @import("image");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const jpeg = @import("jpeg");

const print = std.debug.print;

const helpText =
    \\Usage: zjpeg [options]] <jpeg file>
    \\Options:
    \\  -h, --help  Display this help message
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

    // handle CLI arguments
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try stdout.print(helpText, .{});
            std.process.exit(0);
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

            const img = jpeg.decode(allocator, reader) catch |err| {
                std.log.err("Failed to decode jpeg file: {any}", .{err});
                return err;
            };
            defer img.free(allocator);

            try draw(allocator, arg, img);
        }
    }
}

fn draw(al: std.mem.Allocator, file_name: []const u8, img: image.Image) !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        std.debug.print("Failed to initialize SDL: {s}\n", .{sdl.SDL_GetError()});
        return;
    }
    defer sdl.SDL_Quit();

    const width = img.bounds().dX();
    const height = img.bounds().dY();
    const desired_window_width = 400;
    const desired_window_height = 300;
    const scale_factor = @min(@as(f32, @floatFromInt(width)) / desired_window_width, @as(f32, @floatFromInt(height)) / desired_window_height);

    const window_title = try std.fmt.allocPrintZ(al, "zjpeg view - {s}", .{file_name});
    defer al.free(window_title);

    const window = sdl.SDL_CreateWindow(
        window_title,
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        @as(i32, @intFromFloat(@as(f32, @floatFromInt(width)) / scale_factor)),
        @as(i32, @intFromFloat(@as(f32, @floatFromInt(height)) / scale_factor)),
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

    const pixels = try img.rgbaPixels(al);
    defer al.free(pixels);

    const tex_data: [*]u8 = @ptrCast(tex_pixels);

    var i: usize = 0;
    while (i < pixels.len) : (i += 4) {
        tex_data[i + 0] = pixels[i + 0];
        tex_data[i + 1] = pixels[i + 1];
        tex_data[i + 2] = pixels[i + 2];
        tex_data[i + 3] = pixels[i + 3];
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

test {
    @import("std").testing.refAllDecls(@This());
}
