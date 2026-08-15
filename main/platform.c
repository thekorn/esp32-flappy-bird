#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "driver/gpio.h"
#include "driver/i2c_master.h"
#include "driver/spi_master.h"
#include "esp_check.h"
#include "esp_heap_caps.h"
#include "esp_lcd_panel_io.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "lvgl.h"

#define LCD_WIDTH 320
#define LCD_HEIGHT 172
#define LCD_Y_OFFSET 34
#define LCD_BUFFER_LINES 24

#define BIRD_X 58
#define BIRD_WIDTH 18
#define BIRD_HEIGHT 14
#define PIPE_WIDTH 28
#define PIPE_GAP 58
#define GROUND_Y 154

#define LCD_HOST SPI2_HOST
#define LCD_PIN_SCLK GPIO_NUM_38
#define LCD_PIN_MOSI GPIO_NUM_39
#define LCD_PIN_RST GPIO_NUM_40
#define LCD_PIN_CS GPIO_NUM_21
#define LCD_PIN_DC GPIO_NUM_45
#define LCD_PIN_BL GPIO_NUM_46

#define TOUCH_PIN_SCL GPIO_NUM_41
#define TOUCH_PIN_SDA GPIO_NUM_42
#define TOUCH_PIN_RST GPIO_NUM_47
#define TOUCH_ADDRESS 0x63
#define TOUCH_DATA_REGISTER 0x01

typedef struct {
    uint8_t command;
    uint8_t data[32];
    uint8_t data_length;
    uint16_t delay_ms;
} lcd_init_command_t;

static const char *TAG = "flappy_bird";
static esp_lcd_panel_io_handle_t lcd_io;
static i2c_master_dev_handle_t touch_device;
static lv_disp_drv_t display_driver;
static lv_obj_t *bird;
static lv_obj_t *upper_pipes[2];
static lv_obj_t *lower_pipes[2];
static lv_obj_t *score_label;
static lv_obj_t *message_label;

static const lcd_init_command_t lcd_init_commands[] = {
    {0x11, {}, 0, 120},
    {0xDF, {0x98, 0x53}, 2, 0},
    {0xB2, {0x23}, 1, 0},
    {0xB7, {0x00, 0x47, 0x00, 0x6F}, 4, 0},
    {0xBB, {0x1C, 0x1A, 0x55, 0x73, 0x63, 0xF0}, 6, 0},
    {0xC0, {0x44, 0xA4}, 2, 0},
    {0xC1, {0x16}, 1, 0},
    {0xC3, {0x7D, 0x07, 0x14, 0x06, 0xCF, 0x71, 0x72, 0x77}, 8, 0},
    {0xC4, {0x00, 0x00, 0xA0, 0x79, 0x0B, 0x0A, 0x16, 0x79, 0x0B, 0x0A, 0x16, 0x82}, 12, 0},
    {0xC8, {0x3F, 0x32, 0x29, 0x29, 0x27, 0x2B, 0x27, 0x28,
            0x28, 0x26, 0x25, 0x17, 0x12, 0x0D, 0x04, 0x00,
            0x3F, 0x32, 0x29, 0x29, 0x27, 0x2B, 0x27, 0x28,
            0x28, 0x26, 0x25, 0x17, 0x12, 0x0D, 0x04, 0x00}, 32, 0},
    {0xD0, {0x04, 0x06, 0x6B, 0x0F, 0x00}, 5, 0},
    {0xD7, {0x00, 0x30}, 2, 0},
    {0xE6, {0x14}, 1, 0},
    {0xDE, {0x01}, 1, 0},
    {0xB7, {0x03, 0x13, 0xEF, 0x35, 0x35}, 5, 0},
    {0xC1, {0x14, 0x15, 0xC0}, 3, 0},
    {0xC2, {0x06, 0x3A}, 2, 0},
    {0xC4, {0x72, 0x12}, 2, 0},
    {0xBE, {0x00}, 1, 0},
    {0xDE, {0x02}, 1, 0},
    {0xE5, {0x00, 0x02, 0x00}, 3, 0},
    {0xE5, {0x01, 0x02, 0x00}, 3, 0},
    {0xDE, {0x00}, 1, 0},
    {0x35, {0x00}, 1, 0},
    {0x3A, {0x05}, 1, 0},
    {0x2A, {0x00, 0x22, 0x00, 0xCD}, 4, 0},
    {0x2B, {0x00, 0x00, 0x01, 0x3F}, 4, 0},
    {0xDE, {0x02}, 1, 0},
    {0xE5, {0x00, 0x02, 0x00}, 3, 0},
    {0xDE, {0x00}, 1, 0},
    {0x36, {0x60}, 1, 0},
    {0x21, {}, 0, 10},
    {0x29, {}, 0, 0},
};

static bool lcd_transfer_done(esp_lcd_panel_io_handle_t panel_io,
                              esp_lcd_panel_io_event_data_t *event_data,
                              void *user_ctx)
{
    lv_disp_flush_ready(&display_driver);
    return false;
}

static void lcd_reset(void)
{
    const gpio_config_t reset_config = {
        .pin_bit_mask = 1ULL << LCD_PIN_RST,
        .mode = GPIO_MODE_OUTPUT,
    };
    ESP_ERROR_CHECK(gpio_config(&reset_config));
    ESP_ERROR_CHECK(gpio_set_level(LCD_PIN_RST, 0));
    vTaskDelay(pdMS_TO_TICKS(10));
    ESP_ERROR_CHECK(gpio_set_level(LCD_PIN_RST, 1));
    vTaskDelay(pdMS_TO_TICKS(10));
}

static void lcd_init(void)
{
    const spi_bus_config_t bus_config = {
        .mosi_io_num = LCD_PIN_MOSI,
        .miso_io_num = GPIO_NUM_NC,
        .sclk_io_num = LCD_PIN_SCLK,
        .quadwp_io_num = GPIO_NUM_NC,
        .quadhd_io_num = GPIO_NUM_NC,
        .max_transfer_sz = LCD_WIDTH * LCD_BUFFER_LINES * sizeof(lv_color_t),
    };
    ESP_ERROR_CHECK(spi_bus_initialize(LCD_HOST, &bus_config, SPI_DMA_CH_AUTO));

    const esp_lcd_panel_io_spi_config_t io_config = {
        .cs_gpio_num = LCD_PIN_CS,
        .dc_gpio_num = LCD_PIN_DC,
        .spi_mode = 0,
        .pclk_hz = 40 * 1000 * 1000,
        .trans_queue_depth = 10,
        .on_color_trans_done = lcd_transfer_done,
        .lcd_cmd_bits = 8,
        .lcd_param_bits = 8,
    };
    ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)LCD_HOST,
                                              &io_config, &lcd_io));
    lcd_reset();

    for (size_t i = 0; i < sizeof(lcd_init_commands) / sizeof(lcd_init_commands[0]); i++) {
        const lcd_init_command_t *entry = &lcd_init_commands[i];
        ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(lcd_io, entry->command,
                                                   entry->data, entry->data_length));
        if (entry->delay_ms > 0) {
            vTaskDelay(pdMS_TO_TICKS(entry->delay_ms));
        }
    }

    const gpio_config_t backlight_config = {
        .pin_bit_mask = 1ULL << LCD_PIN_BL,
        .mode = GPIO_MODE_OUTPUT,
    };
    ESP_ERROR_CHECK(gpio_config(&backlight_config));
    ESP_ERROR_CHECK(gpio_set_level(LCD_PIN_BL, 1));
}

static void display_flush(lv_disp_drv_t *driver, const lv_area_t *area,
                          lv_color_t *pixels)
{
    const uint16_t y_start = area->y1 + LCD_Y_OFFSET;
    const uint16_t y_end = area->y2 + LCD_Y_OFFSET;
    const uint8_t columns[] = {area->x1 >> 8, area->x1 & 0xff,
                               area->x2 >> 8, area->x2 & 0xff};
    const uint8_t rows[] = {y_start >> 8, y_start & 0xff, y_end >> 8, y_end & 0xff};
    const size_t pixel_count = (area->x2 - area->x1 + 1) * (area->y2 - area->y1 + 1);

    ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(lcd_io, 0x2A, columns, sizeof(columns)));
    ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(lcd_io, 0x2B, rows, sizeof(rows)));
    ESP_ERROR_CHECK(esp_lcd_panel_io_tx_color(lcd_io, 0x2C, pixels,
                                               pixel_count * sizeof(lv_color_t)));
}

static void touch_init(void)
{
    const gpio_config_t reset_config = {
        .pin_bit_mask = 1ULL << TOUCH_PIN_RST,
        .mode = GPIO_MODE_OUTPUT,
    };
    ESP_ERROR_CHECK(gpio_config(&reset_config));
    ESP_ERROR_CHECK(gpio_set_level(TOUCH_PIN_RST, 0));
    vTaskDelay(pdMS_TO_TICKS(200));
    ESP_ERROR_CHECK(gpio_set_level(TOUCH_PIN_RST, 1));
    vTaskDelay(pdMS_TO_TICKS(300));

    const i2c_master_bus_config_t bus_config = {
        .i2c_port = I2C_NUM_0,
        .sda_io_num = TOUCH_PIN_SDA,
        .scl_io_num = TOUCH_PIN_SCL,
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };
    i2c_master_bus_handle_t bus;
    ESP_ERROR_CHECK(i2c_new_master_bus(&bus_config, &bus));

    const i2c_device_config_t device_config = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = TOUCH_ADDRESS,
        .scl_speed_hz = 400000,
    };
    ESP_ERROR_CHECK(i2c_master_bus_add_device(bus, &device_config, &touch_device));
}

uint8_t platform_touch_pressed(void)
{
    uint8_t touch_data[14];
    const uint8_t register_address = TOUCH_DATA_REGISTER;
    esp_err_t result = i2c_master_transmit(touch_device, &register_address, 1, 100);
    if (result == ESP_OK) {
        result = i2c_master_receive(touch_device, touch_data, sizeof(touch_data), 100);
    }
    if (result != ESP_OK) {
        ESP_LOGW(TAG, "Touch read failed: %s", esp_err_to_name(result));
        return 0;
    }

    return (touch_data[1] & 0x0f) != 0;
}

static void lv_tick(void *arg)
{
    lv_tick_inc(1);
}

static void lvgl_init(void)
{
    lv_init();

    static lv_disp_draw_buf_t draw_buffer;
    lv_color_t *pixels = heap_caps_malloc(LCD_WIDTH * LCD_BUFFER_LINES * sizeof(lv_color_t),
                                           MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
    assert(pixels != NULL);
    lv_disp_draw_buf_init(&draw_buffer, pixels, NULL, LCD_WIDTH * LCD_BUFFER_LINES);

    lv_disp_drv_init(&display_driver);
    display_driver.hor_res = LCD_WIDTH;
    display_driver.ver_res = LCD_HEIGHT;
    display_driver.flush_cb = display_flush;
    display_driver.draw_buf = &draw_buffer;
    lv_disp_drv_register(&display_driver);

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

    const esp_timer_create_args_t tick_timer_args = {
        .callback = lv_tick,
        .name = "lvgl_tick",
    };
    esp_timer_handle_t tick_timer;
    ESP_ERROR_CHECK(esp_timer_create(&tick_timer_args, &tick_timer));
    ESP_ERROR_CHECK(esp_timer_start_periodic(tick_timer, 1000));
}

void platform_init(void)
{
    ESP_LOGI(TAG, "Starting Zig Flappy Bird");
    lcd_init();
    touch_init();
    lvgl_init();
}

static void position_pipe(lv_obj_t *upper, lv_obj_t *lower, int16_t x, int16_t gap_y)
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
        lv_label_set_text(message_label, "FLAPPY BIRD\nTap to fly");
        lv_obj_clear_flag(message_label, LV_OBJ_FLAG_HIDDEN);
    } else if (state == 2) {
        lv_label_set_text(message_label, "GAME OVER\nTap to retry");
        lv_obj_clear_flag(message_label, LV_OBJ_FLAG_HIDDEN);
    } else {
        lv_obj_add_flag(message_label, LV_OBJ_FLAG_HIDDEN);
    }
}

uint64_t platform_millis(void)
{
    return esp_timer_get_time() / 1000;
}

void platform_run(void)
{
    uint32_t delay_ms = lv_timer_handler();
    if (delay_ms < 5) {
        delay_ms = 5;
    } else if (delay_ms > 20) {
        delay_ms = 20;
    }
    vTaskDelay(pdMS_TO_TICKS(delay_ms));
}
