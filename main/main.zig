const std = @import("std");

const lcd_width = 320;
const lcd_height = 172;
const ground_y = 154;
const bird_x = 58;
const bird_width = 18;
const bird_height = 14;
const pipe_width = 28;
const pipe_gap = 58;
const pipe_spacing = 160;
const pipe_speed = 95;
const gravity = 700;
const flap_velocity = -260;
const frame_ms = 16;

const LvObj = opaque {};
const lv_obj_flag_hidden: u32 = 1 << 0;
const lv_obj_flag_scrollable: u32 = 1 << 4;
const lv_align_top_mid: u8 = 2;
const lv_align_center: u8 = 9;
const lv_radius_circle = 0x7fff;

const GameState = enum(u8) {
    ready,
    playing,
    game_over,
};

const Pipe = struct {
    x_milli: i32,
    gap_y: i16,
    scored: bool,
};

extern fn platform_init() void;
extern fn platform_touch_pressed() u8;
extern fn platform_millis() u64;
extern fn platform_run() void;
extern fn platform_screen() *LvObj;
extern fn platform_obj_set_bg_color(object: *LvObj, color: u32) void;
extern fn platform_obj_set_border_color(object: *LvObj, color: u32) void;
extern fn platform_obj_set_text_color(object: *LvObj, color: u32) void;
extern fn platform_obj_set_padding(object: *LvObj, padding: i16) void;

extern fn lv_obj_create(parent: *LvObj) *LvObj;
extern fn lv_label_create(parent: *LvObj) *LvObj;
extern fn lv_label_set_text(object: *LvObj, text: [*:0]const u8) void;
extern fn lv_obj_set_pos(object: *LvObj, x: i16, y: i16) void;
extern fn lv_obj_set_size(object: *LvObj, width: i16, height: i16) void;
extern fn lv_obj_set_y(object: *LvObj, y: i16) void;
extern fn lv_obj_set_width(object: *LvObj, width: i16) void;
extern fn lv_obj_align(object: *LvObj, alignment: u8, x_offset: i16, y_offset: i16) void;
extern fn lv_obj_add_flag(object: *LvObj, flag: u32) void;
extern fn lv_obj_clear_flag(object: *LvObj, flag: u32) void;
extern fn lv_obj_set_style_bg_opa(object: *LvObj, opacity: u8, selector: u32) void;
extern fn lv_obj_set_style_border_width(object: *LvObj, width: i16, selector: u32) void;
extern fn lv_obj_set_style_radius(object: *LvObj, radius: i16, selector: u32) void;
extern fn lv_obj_set_style_text_align(object: *LvObj, alignment: u8, selector: u32) void;

const Ui = struct {
    bird: *LvObj,
    upper_pipes: [2]*LvObj,
    lower_pipes: [2]*LvObj,
    score_label: *LvObj,
    message_label: *LvObj,
};

var ui: Ui = undefined;

var random_state: u32 = 0x6d2b79f5;

fn nextGapY() i16 {
    random_state = random_state *% 1664525 +% 1013904223;
    return 18 + @as(i16, @intCast((random_state >> 16) % 61));
}

fn resetPipes() [2]Pipe {
    return .{
        .{ .x_milli = 210_000, .gap_y = nextGapY(), .scored = false },
        .{ .x_milli = (210 + pipe_spacing) * 1000, .gap_y = nextGapY(), .scored = false },
    };
}

fn overlapsPipe(bird_y: i32, pipe: Pipe) bool {
    const pipe_x = @divTrunc(pipe.x_milli, 1000);
    const horizontal_overlap = bird_x + bird_width > pipe_x and bird_x < pipe_x + pipe_width;
    const vertical_overlap = bird_y < pipe.gap_y or bird_y + bird_height > pipe.gap_y + pipe_gap;
    return horizontal_overlap and vertical_overlap;
}

fn stylePipe(pipe: *LvObj) void {
    lv_obj_clear_flag(pipe, lv_obj_flag_scrollable);
    platform_obj_set_bg_color(pipe, 0x54c84d);
    platform_obj_set_border_color(pipe, 0x27852c);
    lv_obj_set_style_border_width(pipe, 2, 0);
    lv_obj_set_style_radius(pipe, 3, 0);
}

fn createUi() Ui {
    const screen = platform_screen();
    platform_obj_set_bg_color(screen, 0x70c5ce);
    lv_obj_set_style_bg_opa(screen, 255, 0);

    var result: Ui = undefined;
    for (0..2) |index| {
        result.upper_pipes[index] = lv_obj_create(screen);
        result.lower_pipes[index] = lv_obj_create(screen);
        stylePipe(result.upper_pipes[index]);
        stylePipe(result.lower_pipes[index]);
    }

    const ground = lv_obj_create(screen);
    lv_obj_set_pos(ground, 0, ground_y);
    lv_obj_set_size(ground, lcd_width, lcd_height - ground_y);
    lv_obj_clear_flag(ground, lv_obj_flag_scrollable);
    platform_obj_set_bg_color(ground, 0xded895);
    platform_obj_set_border_color(ground, 0x77b255);
    lv_obj_set_style_border_width(ground, 3, 0);
    lv_obj_set_style_radius(ground, 0, 0);

    result.bird = lv_obj_create(screen);
    lv_obj_set_pos(result.bird, bird_x, 72);
    lv_obj_set_size(result.bird, bird_width, bird_height);
    lv_obj_clear_flag(result.bird, lv_obj_flag_scrollable);
    platform_obj_set_bg_color(result.bird, 0xffd83d);
    platform_obj_set_border_color(result.bird, 0xc47c18);
    lv_obj_set_style_border_width(result.bird, 2, 0);
    lv_obj_set_style_radius(result.bird, lv_radius_circle, 0);

    const eye = lv_obj_create(result.bird);
    lv_obj_set_pos(eye, 11, 2);
    lv_obj_set_size(eye, 4, 4);
    lv_obj_clear_flag(eye, lv_obj_flag_scrollable);
    platform_obj_set_bg_color(eye, 0x000000);
    lv_obj_set_style_border_width(eye, 0, 0);
    lv_obj_set_style_radius(eye, lv_radius_circle, 0);
    platform_obj_set_padding(eye, 0);

    result.score_label = lv_label_create(screen);
    platform_obj_set_text_color(result.score_label, 0xffffff);
    lv_obj_set_style_text_align(result.score_label, 2, 0);
    lv_obj_set_width(result.score_label, 60);
    lv_obj_align(result.score_label, lv_align_top_mid, 0, 5);

    result.message_label = lv_label_create(screen);
    platform_obj_set_text_color(result.message_label, 0x174e57);
    lv_obj_set_style_text_align(result.message_label, 2, 0);
    lv_obj_set_width(result.message_label, 150);
    lv_obj_align(result.message_label, lv_align_center, 25, 0);

    return result;
}

fn positionPipe(upper: *LvObj, lower: *LvObj, x: i16, gap_y: i16) void {
    lv_obj_set_pos(upper, x, -2);
    lv_obj_set_size(upper, pipe_width, gap_y + 2);
    lv_obj_set_pos(lower, x, gap_y + pipe_gap);
    lv_obj_set_size(lower, pipe_width, ground_y - gap_y - pipe_gap + 2);
}

fn render(bird_y_milli: i32, pipes: [2]Pipe, score: u16, state: GameState) void {
    lv_obj_set_y(ui.bird, @intCast(@divTrunc(bird_y_milli, 1000)));
    positionPipe(ui.upper_pipes[0], ui.lower_pipes[0], @intCast(@divTrunc(pipes[0].x_milli, 1000)), pipes[0].gap_y);
    positionPipe(ui.upper_pipes[1], ui.lower_pipes[1], @intCast(@divTrunc(pipes[1].x_milli, 1000)), pipes[1].gap_y);

    var score_buffer: [8]u8 = undefined;
    const score_text = std.fmt.bufPrintSentinel(&score_buffer, "{d}", .{score}, 0) catch unreachable;
    lv_label_set_text(ui.score_label, score_text.ptr);

    switch (state) {
        .ready => {
            lv_label_set_text(ui.message_label, "FLAPPY BIRD\nTap to fly");
            lv_obj_clear_flag(ui.message_label, lv_obj_flag_hidden);
        },
        .game_over => {
            lv_label_set_text(ui.message_label, "GAME OVER\nTap to retry");
            lv_obj_clear_flag(ui.message_label, lv_obj_flag_hidden);
        },
        .playing => lv_obj_add_flag(ui.message_label, lv_obj_flag_hidden),
    }
}

pub export fn app_main() void {
    platform_init();
    ui = createUi();

    var state = GameState.ready;
    var bird_y_milli: i32 = 72_000;
    var bird_velocity: i32 = 0;
    var pipes = resetPipes();
    var score: u16 = 0;
    var was_pressed = false;
    var previous_frame = platform_millis();

    render(bird_y_milli, pipes, score, state);

    while (true) {
        const now = platform_millis();
        const is_pressed = platform_touch_pressed() != 0;
        const tapped = is_pressed and !was_pressed;

        if (tapped) {
            switch (state) {
                .ready => {
                    state = .playing;
                    bird_velocity = flap_velocity;
                    previous_frame = now;
                },
                .playing => bird_velocity = flap_velocity,
                .game_over => {
                    bird_y_milli = 72_000;
                    bird_velocity = flap_velocity;
                    pipes = resetPipes();
                    score = 0;
                    state = .playing;
                    previous_frame = now;
                },
            }
        }

        if (state == .playing and now - previous_frame >= frame_ms) {
            const elapsed: i32 = @intCast(@min(now - previous_frame, 50));
            previous_frame = now;

            bird_velocity += @divTrunc(gravity * elapsed, 1000);
            bird_y_milli += bird_velocity * elapsed;

            for (&pipes) |*pipe| {
                const previous_x = pipe.x_milli;
                pipe.x_milli -= pipe_speed * elapsed;

                const bird_x_milli = bird_x * 1000;
                if (!pipe.scored and previous_x >= bird_x_milli and pipe.x_milli < bird_x_milli) {
                    pipe.scored = true;
                    score +|= 1;
                }

                if (@divTrunc(pipe.x_milli, 1000) + pipe_width < 0) {
                    const other_x = if (pipe == &pipes[0]) pipes[1].x_milli else pipes[0].x_milli;
                    pipe.x_milli = other_x + pipe_spacing * 1000;
                    pipe.gap_y = nextGapY();
                    pipe.scored = false;
                }
            }

            const bird_y = @divTrunc(bird_y_milli, 1000);
            if (bird_y <= 0 or bird_y + bird_height >= ground_y or
                overlapsPipe(bird_y, pipes[0]) or overlapsPipe(bird_y, pipes[1]))
            {
                state = .game_over;
            }

            render(bird_y_milli, pipes, score, state);
        }

        was_pressed = is_pressed;
        platform_run();
    }
}
