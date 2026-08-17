// LVGL 8.4 ABI used by the simulator configuration in lv_conf.h.
// The LVGL display structs contain C bit fields, which the Zig C translator exposes
// as opaque types, so the small API surface needed here is declared directly.

pub const lv_obj_t = opaque {};
pub const lv_disp_t = opaque {};
pub const lv_draw_ctx_t = opaque {};

pub const lv_area_t = extern struct {
    x1: i16,
    y1: i16,
    x2: i16,
    y2: i16,
};

pub const lv_color_t = extern union {
    channels: extern struct {
        blue: u8,
        green: u8,
        red: u8,
        alpha: u8,
    },
    full: u32,
};

pub const lv_disp_draw_buf_t = extern struct {
    buf1: ?*anyopaque,
    buf2: ?*anyopaque,
    buf_act: ?*anyopaque,
    size: u32,
    flushing: c_int,
    flushing_last: c_int,
    last_flags: u32,
};

pub const lv_disp_drv_t = extern struct {
    hor_res: i16,
    ver_res: i16,
    physical_hor_res: i16,
    physical_ver_res: i16,
    offset_x: i16,
    offset_y: i16,
    draw_buf: ?*lv_disp_draw_buf_t,
    flags: u32,
    flush_cb: ?*const fn ([*c]lv_disp_drv_t, [*c]const lv_area_t, [*c]lv_color_t) callconv(.c) void,
    rounder_cb: ?*const fn ([*c]lv_disp_drv_t, [*c]lv_area_t) callconv(.c) void,
    set_px_cb: ?*const fn ([*c]lv_disp_drv_t, [*c]u8, i16, i16, i16, lv_color_t, u8) callconv(.c) void,
    clear_cb: ?*const fn ([*c]lv_disp_drv_t, [*c]u8, u32) callconv(.c) void,
    monitor_cb: ?*const fn ([*c]lv_disp_drv_t, u32, u32) callconv(.c) void,
    wait_cb: ?*const fn ([*c]lv_disp_drv_t) callconv(.c) void,
    clean_data_cache_cb: ?*const fn ([*c]lv_disp_drv_t) callconv(.c) void,
    drv_update_cb: ?*const fn ([*c]lv_disp_drv_t) callconv(.c) void,
    render_start_cb: ?*const fn ([*c]lv_disp_drv_t) callconv(.c) void,
    color_chroma_key: lv_color_t,
    draw_ctx: ?*lv_draw_ctx_t,
    draw_ctx_init: ?*const fn ([*c]lv_disp_drv_t, ?*lv_draw_ctx_t) callconv(.c) void,
    draw_ctx_cleanup: ?*const fn ([*c]lv_disp_drv_t, ?*lv_draw_ctx_t) callconv(.c) void,
    draw_ctx_size: usize,
    user_data: ?*anyopaque,
};

pub extern fn lv_init() void;
pub extern fn lv_disp_draw_buf_init(
    draw_buf: *lv_disp_draw_buf_t,
    buf1: ?*anyopaque,
    buf2: ?*anyopaque,
    size_in_px_cnt: u32,
) void;
pub extern fn lv_disp_drv_init(driver: *lv_disp_drv_t) void;
pub extern fn lv_disp_drv_register(driver: *lv_disp_drv_t) ?*lv_disp_t;
pub extern fn lv_disp_flush_is_last(driver: *lv_disp_drv_t) bool;
pub extern fn lv_disp_flush_ready(driver: *lv_disp_drv_t) void;
pub extern fn lv_disp_get_default() ?*lv_disp_t;
pub extern fn lv_disp_get_scr_act(display: ?*lv_disp_t) ?*lv_obj_t;
pub extern fn lv_obj_set_style_bg_color(object: ?*lv_obj_t, color: lv_color_t, selector: u32) void;
pub extern fn lv_obj_set_style_border_color(object: ?*lv_obj_t, color: lv_color_t, selector: u32) void;
pub extern fn lv_obj_set_style_text_color(object: ?*lv_obj_t, color: lv_color_t, selector: u32) void;
pub extern fn lv_obj_set_style_pad_left(object: ?*lv_obj_t, padding: i16, selector: u32) void;
pub extern fn lv_obj_set_style_pad_right(object: ?*lv_obj_t, padding: i16, selector: u32) void;
pub extern fn lv_obj_set_style_pad_top(object: ?*lv_obj_t, padding: i16, selector: u32) void;
pub extern fn lv_obj_set_style_pad_bottom(object: ?*lv_obj_t, padding: i16, selector: u32) void;
pub extern fn lv_tick_inc(milliseconds: u32) void;
pub extern fn lv_timer_handler() u32;

pub fn lv_color_hex(color: u32) lv_color_t {
    return .{ .full = color | 0xff000000 };
}

pub fn lv_scr_act() ?*lv_obj_t {
    return lv_disp_get_scr_act(lv_disp_get_default());
}

pub fn lv_obj_set_style_pad_all(object: ?*lv_obj_t, padding: i16, selector: u32) void {
    lv_obj_set_style_pad_left(object, padding, selector);
    lv_obj_set_style_pad_right(object, padding, selector);
    lv_obj_set_style_pad_top(object, padding, selector);
    lv_obj_set_style_pad_bottom(object, padding, selector);
}

comptime {
    if (@sizeOf(lv_color_t) != 4) @compileError("LVGL simulator color ABI must be 32-bit");

    const is_64_bit = @sizeOf(usize) == 8;
    const expected_draw_buffer_size = if (is_64_bit) 40 else 28;
    const expected_driver_size = if (is_64_bit) 152 else 80;
    if (@sizeOf(lv_disp_draw_buf_t) != expected_draw_buffer_size or
        @offsetOf(lv_disp_draw_buf_t, "buf_act") != 2 * @sizeOf(usize) or
        @offsetOf(lv_disp_draw_buf_t, "size") != 3 * @sizeOf(usize) or
        @sizeOf(lv_disp_drv_t) != expected_driver_size or
        @offsetOf(lv_disp_drv_t, "draw_buf") != (if (is_64_bit) 16 else 12) or
        @offsetOf(lv_disp_drv_t, "flush_cb") != (if (is_64_bit) 32 else 20) or
        @offsetOf(lv_disp_drv_t, "color_chroma_key") != (if (is_64_bit) 104 else 56) or
        @offsetOf(lv_disp_drv_t, "user_data") != (if (is_64_bit) 144 else 76))
    {
        @compileError("LVGL simulator display ABI layout mismatch");
    }
}
