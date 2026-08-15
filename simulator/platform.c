#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <SDL.h>
#include "lvgl.h"

#define LCD_WIDTH 320
#define LCD_HEIGHT 172
#define WINDOW_SCALE 3

static SDL_Window *window;
static SDL_Renderer *renderer;
static SDL_Texture *texture;
static bool pressed;
static uint64_t previous_tick;

extern void app_main(void);

static void display_flush(lv_disp_drv_t *driver, const lv_area_t *area,
                          lv_color_t *pixels)
{
    const SDL_Rect rectangle = {
        .x = area->x1,
        .y = area->y1,
        .w = area->x2 - area->x1 + 1,
        .h = area->y2 - area->y1 + 1,
    };

    SDL_UpdateTexture(texture, &rectangle, pixels,
                      rectangle.w * (int)sizeof(lv_color_t));
    if (lv_disp_flush_is_last(driver)) {
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }
    lv_disp_flush_ready(driver);
}

void platform_init(void)
{
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "SDL initialization failed: %s\n", SDL_GetError());
        exit(EXIT_FAILURE);
    }

    window = SDL_CreateWindow("Zig Flappy Bird", SDL_WINDOWPOS_CENTERED,
                              SDL_WINDOWPOS_CENTERED,
                              LCD_WIDTH * WINDOW_SCALE,
                              LCD_HEIGHT * WINDOW_SCALE, 0);
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (renderer == NULL) {
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    }
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                SDL_TEXTUREACCESS_STREAMING,
                                LCD_WIDTH, LCD_HEIGHT);
    if (window == NULL || renderer == NULL || texture == NULL) {
        fprintf(stderr, "SDL display creation failed: %s\n", SDL_GetError());
        exit(EXIT_FAILURE);
    }

    lv_init();
    static lv_color_t pixels[LCD_WIDTH * LCD_HEIGHT];
    static lv_disp_draw_buf_t draw_buffer;
    static lv_disp_drv_t display_driver;
    lv_disp_draw_buf_init(&draw_buffer, pixels, NULL, LCD_WIDTH * LCD_HEIGHT);
    lv_disp_drv_init(&display_driver);
    display_driver.hor_res = LCD_WIDTH;
    display_driver.ver_res = LCD_HEIGHT;
    display_driver.flush_cb = display_flush;
    display_driver.draw_buf = &draw_buffer;
    lv_disp_drv_register(&display_driver);

    previous_tick = SDL_GetTicks64();
}

uint8_t platform_touch_pressed(void)
{
    return pressed;
}

lv_obj_t *platform_screen(void)
{
    return lv_scr_act();
}

void platform_obj_set_bg_color(lv_obj_t *object, uint32_t color)
{
    lv_obj_set_style_bg_color(object, lv_color_hex(color), 0);
}

void platform_obj_set_border_color(lv_obj_t *object, uint32_t color)
{
    lv_obj_set_style_border_color(object, lv_color_hex(color), 0);
}

void platform_obj_set_text_color(lv_obj_t *object, uint32_t color)
{
    lv_obj_set_style_text_color(object, lv_color_hex(color), 0);
}

void platform_obj_set_padding(lv_obj_t *object, int16_t padding)
{
    lv_obj_set_style_pad_all(object, padding, 0);
}

uint64_t platform_millis(void)
{
    return SDL_GetTicks64();
}

void platform_run(void)
{
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_QUIT:
                exit(EXIT_SUCCESS);
            case SDL_MOUSEBUTTONDOWN:
                if (event.button.button == SDL_BUTTON_LEFT) {
                    pressed = true;
                }
                break;
            case SDL_MOUSEBUTTONUP:
                if (event.button.button == SDL_BUTTON_LEFT) {
                    pressed = false;
                }
                break;
            case SDL_KEYDOWN:
                if (event.key.keysym.sym == SDLK_SPACE && !event.key.repeat) {
                    pressed = true;
                }
                break;
            case SDL_KEYUP:
                if (event.key.keysym.sym == SDLK_SPACE) {
                    pressed = false;
                }
                break;
        }
    }

    const uint64_t now = SDL_GetTicks64();
    lv_tick_inc((uint32_t)(now - previous_tick));
    previous_tick = now;
    lv_timer_handler();
    SDL_Delay(5);
}

int main(void)
{
    app_main();
    return 0;
}
