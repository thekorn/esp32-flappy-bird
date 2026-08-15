const game = @import("game");
const c = @import("c");

const lcd_width = 320;
const lcd_height = 172;
const window_scale = 3;

var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var texture: ?*c.SDL_Texture = null;
var pressed = false;
var previous_tick: u64 = 0;
var pixels: [lcd_width * lcd_height]u32 = undefined;

fn fail(message: [*:0]const u8) noreturn {
    c.SDL_Log(message, c.SDL_GetError());
    c.exit(c.EXIT_FAILURE);
}

fn displayFlush(
    driver: ?*anyopaque,
    area: [*c]const c.simulator_area_t,
    pixel_data: [*c]u32,
) callconv(.c) void {
    const rectangle = c.SDL_Rect{
        .x = area.*.x1,
        .y = area.*.y1,
        .w = area.*.x2 - area.*.x1 + 1,
        .h = area.*.y2 - area.*.y1 + 1,
    };

    _ = c.SDL_UpdateTexture(
        texture,
        &rectangle,
        pixel_data,
        rectangle.w * @sizeOf(u32),
    );
    if (c.simulator_flush_is_last(driver) != 0) {
        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderCopy(renderer, texture, null, null);
        c.SDL_RenderPresent(renderer);
    }
    c.simulator_flush_ready(driver);
}

export fn platform_init() void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER) != 0) {
        fail("SDL initialization failed: %s");
    }

    window = c.SDL_CreateWindow(
        "Zig Flappy Bird",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        lcd_width * window_scale,
        lcd_height * window_scale,
        0,
    );
    if (window == null) fail("SDL window creation failed: %s");

    renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED);
    if (renderer == null) {
        renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_SOFTWARE);
    }
    if (renderer == null) fail("SDL renderer creation failed: %s");

    texture = c.SDL_CreateTexture(
        renderer,
        c.SDL_PIXELFORMAT_ARGB8888,
        c.SDL_TEXTUREACCESS_STREAMING,
        lcd_width,
        lcd_height,
    );
    if (texture == null) fail("SDL texture creation failed: %s");

    c.simulator_lvgl_init(&pixels, pixels.len, lcd_width, lcd_height, displayFlush);

    previous_tick = c.SDL_GetTicks64();
}

export fn platform_touch_pressed() u8 {
    return @intFromBool(pressed);
}

export fn platform_screen() ?*anyopaque {
    return c.simulator_screen();
}

export fn platform_obj_set_bg_color(object: ?*anyopaque, color: u32) void {
    c.simulator_obj_set_bg_color(object, color);
}

export fn platform_obj_set_border_color(object: ?*anyopaque, color: u32) void {
    c.simulator_obj_set_border_color(object, color);
}

export fn platform_obj_set_text_color(object: ?*anyopaque, color: u32) void {
    c.simulator_obj_set_text_color(object, color);
}

export fn platform_obj_set_padding(object: ?*anyopaque, padding: i16) void {
    c.simulator_obj_set_padding(object, padding);
}

export fn platform_millis() u64 {
    return c.SDL_GetTicks64();
}

export fn platform_run() void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_QUIT => c.exit(c.EXIT_SUCCESS),
            c.SDL_MOUSEBUTTONDOWN => {
                if (event.button.button == c.SDL_BUTTON_LEFT) pressed = true;
            },
            c.SDL_MOUSEBUTTONUP => {
                if (event.button.button == c.SDL_BUTTON_LEFT) pressed = false;
            },
            c.SDL_KEYDOWN => {
                if (event.key.keysym.sym == c.SDLK_SPACE and event.key.repeat == 0) pressed = true;
            },
            c.SDL_KEYUP => {
                if (event.key.keysym.sym == c.SDLK_SPACE) pressed = false;
            },
            else => {},
        }
    }

    const now = c.SDL_GetTicks64();
    c.simulator_tick_inc(@intCast(now - previous_tick));
    previous_tick = now;
    c.simulator_timer_handler();
    c.SDL_Delay(5);
}

pub export fn main() c_int {
    game.app_main();
    return 0;
}
