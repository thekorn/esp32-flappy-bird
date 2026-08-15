const hello: [:0]const u8 = "hello world";
const touched: [:0]const u8 = "touched";
const touched_duration_ms = 2000;

extern fn platform_init() void;
extern fn platform_set_label(text: [*:0]const u8) void;
extern fn platform_touch_pressed() u8;
extern fn platform_millis() u64;
extern fn platform_run() void;

export fn app_main() void {
    platform_init();
    platform_set_label(hello.ptr);

    var was_pressed = false;
    var showing_touched = false;
    var restore_at: u64 = 0;

    while (true) {
        const now = platform_millis();
        const is_pressed = platform_touch_pressed() != 0;

        if (is_pressed and !was_pressed) {
            platform_set_label(touched.ptr);
            restore_at = now + touched_duration_ms;
            showing_touched = true;
        }

        if (showing_touched and now >= restore_at) {
            platform_set_label(hello.ptr);
            showing_touched = false;
        }

        was_pressed = is_pressed;
        platform_run();
    }
}
