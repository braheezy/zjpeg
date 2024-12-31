# zjpeg

A JPEG decoder in pure Zig. It supports:

- Baseline and Progressive formats
- Grey and YCbCr color formats.

Here's proof. The Mac image viewer on the left, and a SDL image viewer in Zig using `zjpeg`:
![demo](demo.png)

## Development

Run using `zig`:

    zig build run -- <input jpeg>

Or build and run:

    zig build
    ./zig-out/bin/zjpeg <input jpeg>

---
