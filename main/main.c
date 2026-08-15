#include "esp_log.h"

extern const char *zig_hello_message(void);

void app_main(void)
{
    ESP_LOGI("hello_zig", "%s", zig_hello_message());
}
