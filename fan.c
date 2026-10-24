sudo nano fan_ctrl.c

#include <gpiod.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <math.h>
#include <time.h>

// Pro Raspberry Pi 3/4 64-bit pouzijte "/dev/gpiochip0"
// Pro Raspberry Pi 5 pouzijte "/dev/gpiochip4"
#define CHIP_PATH "/dev/gpiochip0"
#define PIN 18
#define FREQ 20
#define TEMP_MIN 50.0
#define TEMP_MAX 60.0
#define HYSTERESIS 1.0     
#define KICK_TIME 2        
#define SHM_PATH "/fan_status"

#define START_HOUR 6
#define STOP_HOUR 21

typedef struct {
    float duty; // Otacky 0.0 az 1.0
} fan_state_t;

float get_temp() {
    FILE *f = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (!f) return 0;
    int temp_raw = 0;
    if (fscanf(f, "%d", &temp_raw) != 1) temp_raw = 0;
    fclose(f);
    return temp_raw / 1000.0;
}

int is_operating_time() {
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    return (tm_info->tm_hour >= START_HOUR && tm_info->tm_hour < STOP_HOUR);
}

int main() {
    struct gpiod_chip *chip = gpiod_chip_open(CHIP_PATH);
    if (!chip) {
        perror("Chyba pri otevirani GPIO mezipameti/cipu");
        return 1;
    }

    struct gpiod_line_settings *settings = gpiod_line_settings_new();
    gpiod_line_settings_set_direction(settings, GPIOD_LINE_DIRECTION_OUTPUT);
    gpiod_line_settings_set_output_value(settings, GPIOD_LINE_VALUE_INACTIVE);

    struct gpiod_line_config *line_cfg = gpiod_line_config_new();
    unsigned int offsets[] = { PIN };
    gpiod_line_config_add_line_settings(line_cfg, offsets, 1, settings);

    struct gpiod_request_config *req_cfg = gpiod_request_config_new();
    gpiod_request_config_set_consumer(req_cfg, "fan_ctrl");

    struct gpiod_line_request *request = gpiod_chip_request_lines(chip, req_cfg, line_cfg);

    gpiod_request_config_free(req_cfg);
    gpiod_line_config_free(line_cfg);
    gpiod_line_settings_free(settings);

    if (!request) {
        perror("Chyba pri pozadavku na GPIO linku");
        gpiod_chip_close(chip);
        return 1;
    }

    int shm_fd = shm_open(SHM_PATH, O_CREAT | O_RDWR, 0666);
    if (shm_fd >= 0) {
        ftruncate(shm_fd, sizeof(fan_state_t));
    }
    fan_state_t *state = mmap(0, sizeof(fan_state_t), PROT_WRITE, MAP_SHARED, shm_fd, 0);

    float current_duty = 0.0;
    float last_temp_target = 0;
    int was_off = 1;

    while (1) {
        float temp = get_temp();
        
        if (is_operating_time()) {
            if (was_off) {
                gpiod_line_request_set_value(request, PIN, GPIOD_LINE_VALUE_ACTIVE);
                sleep(KICK_TIME);
                was_off = 0;
                current_duty = 0.2;
            }

            if (fabs(temp - last_temp_target) > HYSTERESIS) {
                float target_duty = 0.2;

                if (temp >= TEMP_MAX) {
                    target_duty = 1.0;
                } else if (temp > TEMP_MIN) {
                    float raw_duty = 0.2 + (temp - TEMP_MIN) * 0.8 / (TEMP_MAX - TEMP_MIN);
                    target_duty = roundf(raw_duty * 10.0) / 10.0;
                }

                current_duty = target_duty;
                last_temp_target = temp; 
            }
        } else {
            current_duty = 0.0;
            was_off = 1;
        }

        if (state != MAP_FAILED) {
            state->duty = current_duty;
        }

        if (current_duty <= 0.0) {
            gpiod_line_request_set_value(request, PIN, GPIOD_LINE_VALUE_INACTIVE);
            sleep(1); 
            continue;
        }

        long period_us = 1000000 / FREQ;
        long on_us = period_us * current_duty;
        long off_us = period_us - on_us;

        for (int i = 0; i < FREQ; i++) {
            gpiod_line_request_set_value(request, PIN, GPIOD_LINE_VALUE_ACTIVE);
            usleep(on_us);
            gpiod_line_request_set_value(request, PIN, GPIOD_LINE_VALUE_INACTIVE);
            usleep(off_us);
        }
    }

    gpiod_line_request_release(request);
    gpiod_chip_close(chip);
    return 0;
}


sudo apt update && sudo apt install -y gpiod libgpiod-dev

gcc -o fan_ctrl fan_ctrl.c -lgpiod -lrt -lm

sudo mv fan_ctrl /usr/local/bin/
sudo chown root:root /usr/local/bin/fan_ctrl
sudo chmod +x /usr/local/bin/fan_ctrl

sudo bash -c 'cat <<EOF > /etc/systemd/system/fan.service
[Unit]
Description=C-based Fan Control PWM 20Hz
After=network.target

[Service]
ExecStart=/usr/local/bin/fan_ctrl
Restart=always
RestartSec=5
User=root
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable --now fan.service
