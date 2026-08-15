const greeting: [:0]const u8 = "Hello, world from Zig on ESP32-S3!";

export fn zig_hello_message() [*:0]const u8 {
    return greeting.ptr;
}
