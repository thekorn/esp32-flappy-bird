#include "bindings.h"

#include "lvgl.h"

static lv_disp_draw_buf_t draw_buffer;
static lv_disp_drv_t display_driver;

void simulator_lvgl_init(uint32_t *pixels, uint32_t pixel_count,
                         int16_t width, int16_t height,
                         simulator_flush_cb_t flush_cb)
{
    _Static_assert(sizeof(lv_color_t) == sizeof(*pixels),
                   "Simulator requires 32-bit LVGL color");
    _Static_assert(sizeof(lv_area_t) == sizeof(simulator_area_t),
                   "Simulator area must match LVGL area");

    lv_init();
    lv_disp_draw_buf_init(&draw_buffer, pixels, NULL, pixel_count);
    lv_disp_drv_init(&display_driver);
    display_driver.hor_res = width;
    display_driver.ver_res = height;
    display_driver.flush_cb = (void (*)(lv_disp_drv_t *, const lv_area_t *, lv_color_t *))flush_cb;
    display_driver.draw_buf = &draw_buffer;
    lv_disp_drv_register(&display_driver);
}

void *simulator_screen(void)
{
    return lv_scr_act();
}

void simulator_obj_set_bg_color(void *object, uint32_t color)
{
    lv_obj_set_style_bg_color(object, lv_color_hex(color), 0);
}

void simulator_obj_set_border_color(void *object, uint32_t color)
{
    lv_obj_set_style_border_color(object, lv_color_hex(color), 0);
}

void simulator_obj_set_text_color(void *object, uint32_t color)
{
    lv_obj_set_style_text_color(object, lv_color_hex(color), 0);
}

void simulator_obj_set_padding(void *object, int16_t padding)
{
    lv_obj_set_style_pad_all(object, padding, 0);
}

int simulator_flush_is_last(void *driver)
{
    return lv_disp_flush_is_last(driver);
}

void simulator_flush_ready(void *driver)
{
    lv_disp_flush_ready(driver);
}

void simulator_tick_inc(uint32_t milliseconds)
{
    lv_tick_inc(milliseconds);
}

void simulator_timer_handler(void)
{
    lv_timer_handler();
}
