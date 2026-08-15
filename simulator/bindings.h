#pragma once

#include <SDL2/SDL.h>
#include <stdint.h>

typedef struct {
    int16_t x1;
    int16_t y1;
    int16_t x2;
    int16_t y2;
} simulator_area_t;

typedef void (*simulator_flush_cb_t)(void *driver,
                                     const simulator_area_t *area,
                                     uint32_t *pixels);

void simulator_lvgl_init(uint32_t *pixels, uint32_t pixel_count,
                         int16_t width, int16_t height,
                         simulator_flush_cb_t flush_cb);
void *simulator_screen(void);
void simulator_obj_set_bg_color(void *object, uint32_t color);
void simulator_obj_set_border_color(void *object, uint32_t color);
void simulator_obj_set_text_color(void *object, uint32_t color);
void simulator_obj_set_padding(void *object, int16_t padding);
int simulator_flush_is_last(void *driver);
void simulator_flush_ready(void *driver);
void simulator_tick_inc(uint32_t milliseconds);
void simulator_timer_handler(void);
