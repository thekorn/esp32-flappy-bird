const std = @import("std");

pub const Event = enum {
    mouse_button_down,
    mouse_button_up,
    space_down,
    space_repeat,
    space_up,
};

pub fn nextPressed(current: bool, event: Event) bool {
    return switch (event) {
        .mouse_button_down, .space_down => true,
        .mouse_button_up, .space_up => false,
        .space_repeat => current,
    };
}

test "left mouse button controls touch state" {
    var pressed = false;

    pressed = nextPressed(pressed, .mouse_button_down);
    try std.testing.expect(pressed);

    pressed = nextPressed(pressed, .mouse_button_up);
    try std.testing.expect(!pressed);
}

test "space bar controls touch state" {
    var pressed = false;

    pressed = nextPressed(pressed, .space_down);
    try std.testing.expect(pressed);

    pressed = nextPressed(pressed, .space_up);
    try std.testing.expect(!pressed);
}

test "repeated space keydown preserves touch state" {
    try std.testing.expect(!nextPressed(false, .space_repeat));
    try std.testing.expect(nextPressed(true, .space_repeat));
}
