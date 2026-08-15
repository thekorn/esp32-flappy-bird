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
extern fn platform_render_game(
    bird_y: i16,
    pipe_1_x: i16,
    pipe_1_gap_y: i16,
    pipe_2_x: i16,
    pipe_2_gap_y: i16,
    score: u16,
    state: u8,
) void;
extern fn platform_run() void;

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

fn render(bird_y_milli: i32, pipes: [2]Pipe, score: u16, state: GameState) void {
    platform_render_game(
        @intCast(@divTrunc(bird_y_milli, 1000)),
        @intCast(@divTrunc(pipes[0].x_milli, 1000)),
        pipes[0].gap_y,
        @intCast(@divTrunc(pipes[1].x_milli, 1000)),
        pipes[1].gap_y,
        score,
        @intFromEnum(state),
    );
}

export fn app_main() void {
    platform_init();

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
