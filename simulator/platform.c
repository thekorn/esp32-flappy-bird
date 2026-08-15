#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <SDL.h>
#include "lvgl.h"

#define LCD_WIDTH 320
#define LCD_HEIGHT 172
#define WINDOW_SCALE 3

#define BIRD_X 58
#define BIRD_WIDTH 18
#define BIRD_HEIGHT 14
#define PIPE_WIDTH 28
#define PIPE_GAP 58
#define GROUND_Y 154

static SDL_Window *window;
static SDL_Renderer *renderer;
static SDL_Texture *texture;
static bool pressed;
static uint64_t previous_tick;

static lv_obj_t *bird;
static lv_obj_t *upper_pipes[2];
static lv_obj_t *lower_pipes[2];
static lv_obj_t *score_label;
static lv_obj_t *message_label;

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

static void create_game_objects(void)
{
    lv_obj_t *screen = lv_scr_act();
    lv_obj_set_style_bg_color(screen, lv_color_hex(0x70C5CE), 0);
    lv_obj_set_style_bg_opa(screen, LV_OPA_COVER, 0);

    for (size_t i = 0; i < 2; i++) {
        upper_pipes[i] = lv_obj_create(screen);
        lower_pipes[i] = lv_obj_create(screen);
        lv_obj_clear_flag(upper_pipes[i], LV_OBJ_FLAG_SCROLLABLE);
        lv_obj_clear_flag(lower_pipes[i], LV_OBJ_FLAG_SCROLLABLE);
        lv_obj_set_style_bg_color(upper_pipes[i], lv_color_hex(0x54C84D), 0);
        lv_obj_set_style_bg_color(lower_pipes[i], lv_color_hex(0x54C84D), 0);
        lv_obj_set_style_border_color(upper_pipes[i], lv_color_hex(0x27852C), 0);
        lv_obj_set_style_border_color(lower_pipes[i], lv_color_hex(0x27852C), 0);
        lv_obj_set_style_border_width(upper_pipes[i], 2, 0);
        lv_obj_set_style_border_width(lower_pipes[i], 2, 0);
        lv_obj_set_style_radius(upper_pipes[i], 3, 0);
        lv_obj_set_style_radius(lower_pipes[i], 3, 0);
    }

    lv_obj_t *ground = lv_obj_create(screen);
    lv_obj_set_pos(ground, 0, GROUND_Y);
    lv_obj_set_size(ground, LCD_WIDTH, LCD_HEIGHT - GROUND_Y);
    lv_obj_clear_flag(ground, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_bg_color(ground, lv_color_hex(0xDED895), 0);
    lv_obj_set_style_border_color(ground, lv_color_hex(0x77B255), 0);
    lv_obj_set_style_border_width(ground, 3, 0);
    lv_obj_set_style_radius(ground, 0, 0);

    bird = lv_obj_create(screen);
    lv_obj_set_pos(bird, BIRD_X, 72);
    lv_obj_set_size(bird, BIRD_WIDTH, BIRD_HEIGHT);
    lv_obj_clear_flag(bird, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_bg_color(bird, lv_color_hex(0xFFD83D), 0);
    lv_obj_set_style_border_color(bird, lv_color_hex(0xC47C18), 0);
    lv_obj_set_style_border_width(bird, 2, 0);
    lv_obj_set_style_radius(bird, LV_RADIUS_CIRCLE, 0);

    lv_obj_t *eye = lv_obj_create(bird);
    lv_obj_set_pos(eye, 11, 2);
    lv_obj_set_size(eye, 4, 4);
    lv_obj_clear_flag(eye, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_bg_color(eye, lv_color_black(), 0);
    lv_obj_set_style_border_width(eye, 0, 0);
    lv_obj_set_style_radius(eye, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_pad_all(eye, 0, 0);

    score_label = lv_label_create(screen);
    lv_obj_set_style_text_color(score_label, lv_color_white(), 0);
    lv_obj_set_style_text_align(score_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_width(score_label, 60);
    lv_obj_align(score_label, LV_ALIGN_TOP_MID, 0, 5);

    message_label = lv_label_create(screen);
    lv_obj_set_style_text_color(message_label, lv_color_hex(0x174E57), 0);
    lv_obj_set_style_text_align(message_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_width(message_label, 150);
    lv_obj_align(message_label, LV_ALIGN_CENTER, 25, 0);
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

    create_game_objects();
    previous_tick = SDL_GetTicks64();
}

uint8_t platform_touch_pressed(void)
{
    return pressed;
}

static void position_pipe(lv_obj_t *upper, lv_obj_t *lower,
                          int16_t x, int16_t gap_y)
{
    lv_obj_set_pos(upper, x, -2);
    lv_obj_set_size(upper, PIPE_WIDTH, gap_y + 2);
    lv_obj_set_pos(lower, x, gap_y + PIPE_GAP);
    lv_obj_set_size(lower, PIPE_WIDTH, GROUND_Y - gap_y - PIPE_GAP + 2);
}

void platform_render_game(int16_t bird_y,
                          int16_t pipe_1_x, int16_t pipe_1_gap_y,
                          int16_t pipe_2_x, int16_t pipe_2_gap_y,
                          uint16_t score, uint8_t state)
{
    char score_text[8];
    snprintf(score_text, sizeof(score_text), "%u", score);

    lv_obj_set_y(bird, bird_y);
    position_pipe(upper_pipes[0], lower_pipes[0], pipe_1_x, pipe_1_gap_y);
    position_pipe(upper_pipes[1], lower_pipes[1], pipe_2_x, pipe_2_gap_y);
    lv_label_set_text(score_label, score_text);

    if (state == 0) {
        lv_label_set_text(message_label, "FLAPPY BIRD\nClick to fly");
        lv_obj_clear_flag(message_label, LV_OBJ_FLAG_HIDDEN);
    } else if (state == 2) {
        lv_label_set_text(message_label, "GAME OVER\nClick to retry");
        lv_obj_clear_flag(message_label, LV_OBJ_FLAG_HIDDEN);
    } else {
        lv_obj_add_flag(message_label, LV_OBJ_FLAG_HIDDEN);
    }
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
