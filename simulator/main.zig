const std = @import("std");
const game = @import("game");
const input = @import("input.zig");
const lvgl = @import("lvgl");
const sdl = @import("sdl");

const lcd_width = 320;
const lcd_height = 172;
const window_scale = 3;

var window: ?*sdl.SDL_Window = null;
var renderer: ?*sdl.SDL_Renderer = null;
var texture: ?*sdl.SDL_Texture = null;
var pressed = false;
var previous_tick: u64 = 0;
var draw_buffer: lvgl.lv_disp_draw_buf_t = undefined;
var display_driver: lvgl.lv_disp_drv_t = undefined;
var pixels: [lcd_width * lcd_height]lvgl.lv_color_t = undefined;

fn fail(message: [*:0]const u8) noreturn {
    sdl.SDL_Log(message, sdl.SDL_GetError());
    std.process.exit(1);
}

fn displayFlush(
    driver: [*c]lvgl.lv_disp_drv_t,
    area: [*c]const lvgl.lv_area_t,
    pixel_data: [*c]lvgl.lv_color_t,
) callconv(.c) void {
    const rectangle = sdl.SDL_Rect{
        .x = area.*.x1,
        .y = area.*.y1,
        .w = area.*.x2 - area.*.x1 + 1,
        .h = area.*.y2 - area.*.y1 + 1,
    };

    _ = sdl.SDL_UpdateTexture(
        texture,
        &rectangle,
        pixel_data,
        rectangle.w * @sizeOf(lvgl.lv_color_t),
    );
    if (lvgl.lv_disp_flush_is_last(driver)) {
        _ = sdl.SDL_RenderClear(renderer);
        _ = sdl.SDL_RenderTexture(renderer, texture, null, null);
        _ = sdl.SDL_RenderPresent(renderer);
    }
    lvgl.lv_disp_flush_ready(driver);
}

export fn platform_init() void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        fail("SDL initialization failed: %s");
    }

    window = sdl.SDL_CreateWindow(
        "Zig Flappy Bird",
        lcd_width * window_scale,
        lcd_height * window_scale,
        0,
    );
    if (window == null) fail("SDL window creation failed: %s");

    renderer = sdl.SDL_CreateRenderer(window, null);
    if (renderer == null) fail("SDL renderer creation failed: %s");

    texture = sdl.SDL_CreateTexture(
        renderer,
        sdl.SDL_PIXELFORMAT_ARGB8888,
        sdl.SDL_TEXTUREACCESS_STREAMING,
        lcd_width,
        lcd_height,
    );
    if (texture == null) fail("SDL texture creation failed: %s");

    lvgl.lv_init();
    lvgl.lv_disp_draw_buf_init(&draw_buffer, &pixels, null, pixels.len);
    lvgl.lv_disp_drv_init(&display_driver);
    display_driver.hor_res = lcd_width;
    display_driver.ver_res = lcd_height;
    display_driver.flush_cb = displayFlush;
    display_driver.draw_buf = &draw_buffer;
    _ = lvgl.lv_disp_drv_register(&display_driver);

    previous_tick = sdl.SDL_GetTicks();
}

export fn platform_touch_pressed() u8 {
    return @intFromBool(pressed);
}

export fn platform_screen() ?*anyopaque {
    return lvgl.lv_scr_act();
}

export fn platform_obj_set_bg_color(object: ?*anyopaque, color: u32) void {
    lvgl.lv_obj_set_style_bg_color(@ptrCast(object), lvgl.lv_color_hex(color), 0);
}

export fn platform_obj_set_border_color(object: ?*anyopaque, color: u32) void {
    lvgl.lv_obj_set_style_border_color(@ptrCast(object), lvgl.lv_color_hex(color), 0);
}

export fn platform_obj_set_text_color(object: ?*anyopaque, color: u32) void {
    lvgl.lv_obj_set_style_text_color(@ptrCast(object), lvgl.lv_color_hex(color), 0);
}

export fn platform_obj_set_padding(object: ?*anyopaque, padding: i16) void {
    lvgl.lv_obj_set_style_pad_all(@ptrCast(object), padding, 0);
}

export fn platform_millis() u64 {
    return sdl.SDL_GetTicks();
}

export fn platform_run() void {
    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.SDL_EVENT_QUIT => std.process.exit(0),
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                if (event.button.button == sdl.SDL_BUTTON_LEFT) {
                    pressed = input.nextPressed(pressed, .mouse_button_down);
                }
            },
            sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                if (event.button.button == sdl.SDL_BUTTON_LEFT) {
                    pressed = input.nextPressed(pressed, .mouse_button_up);
                }
            },
            sdl.SDL_EVENT_KEY_DOWN => {
                if (event.key.key == sdl.SDLK_SPACE) {
                    const input_event: input.Event = if (event.key.repeat) .space_repeat else .space_down;
                    pressed = input.nextPressed(pressed, input_event);
                }
            },
            sdl.SDL_EVENT_KEY_UP => {
                if (event.key.key == sdl.SDLK_SPACE) {
                    pressed = input.nextPressed(pressed, .space_up);
                }
            },
            else => {},
        }
    }

    const now = sdl.SDL_GetTicks();
    lvgl.lv_tick_inc(@intCast(now - previous_tick));
    previous_tick = now;
    _ = lvgl.lv_timer_handler();
    sdl.SDL_Delay(5);
}

pub export fn main() c_int {
    game.app_main();
    return 0;
}
