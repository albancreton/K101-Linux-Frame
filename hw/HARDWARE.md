# K101 photo frame — hardware notes

Extracted 2026-10-27 from the stock Android 6.0.1 image (`6.0.1_K101_Kelarior1.0.2_V260725`)
via ADB (root). Raw sources in this directory:

- `sys_config_dump.txt` — Allwinner sys_config, dumped section by section via `/sys/class/script/dump`
- `modules/` — vendor kernel modules (`lcd.ko`, `gslX680new.ko`, `disp.ko`, `mir3da.ko`, `8188fu.ko`).
  Not in the repository; pull them from a stock frame with
  `adb pull /system/vendor/modules/<name>.ko hw/modules/`
- `jyx_init_raw.txt` — panel init table decoded from `lcd.ko` (`dj9365da_h3_jyx`, table at .data+0xdce8)
- `firmware/silead/gsl1680-k101-frame.fw` — touch firmware (`GSL1680F_ZSK_1975` from `gslX680new.ko`), mainline `silead` format

## SoC / board

| | |
|---|---|
| SoC | Allwinner A33 (sun8iw5, "astar"), 4× Cortex-A7 @ 1.344 GHz, Mali-400 MP2 |
| RAM | 1 GB DDR3 |
| Storage | raw NAND (Allwinner proprietary FTL) — leave untouched |
| Stock kernel | Linux 3.4.39 BSP |
| Debug UART | UART0 on PB0 (TX) / PB1 (RX), 115200 |

## DRAM (for U-Boot SPL)

`dram_clk=552`, `dram_type=3` (DDR3), `dram_zq=31675` (0x7bbb), `dram_odt_en=1`,
`dram_para1=0x10f40400`, `dram_para2=0`, `dram_tpr13=257`.

## SD card (boot medium)

SDC0 on PF0–PF5, 4-bit, card-detect PB4 (active-low, pull-up), powered from `dcdc1` (3.0 V).
Verified: SDHC detected at SD-HS 50 MHz 4-bit, ~18 MB/s read.

## PMIC — AXP223 (on RSB, PL0/PL1)

| Rail | Voltage | Use |
|---|---|---|
| dcdc1 | 3.0 V | IO / SD / USB |
| dcdc2 | 1.1 V | sys |
| dcdc3 | 1.2–1.32 V | CPU (1.32 V at 1.2 GHz) |
| dcdc5 | 1.5 V | DRAM |
| aldo2 | 2.5 V | |
| aldo3 | 3.0 V | |
| dc1sw | — | LCD power |
| eldo1 | off | named as LCD power 1, unused by stock firmware |
| ldo_io1 | 3.3 V | touch controller |

Battery-less (`pmu_batdeten=0`, charging disabled).

## Display — MIPI-DSI, 4 lanes

- Native 800×1280 portrait, mounted with the panel's left side up (its top is on the frame's right):
  DT `rotation = <270>`, console `fbcon=rotate:1`.
- Controller **JD9365DA-H3** (vendor driver `dj9365da_h3_jyx`; its init table starts `E0 00, E1 93, E2 65, E3 F8`). Note: in `lcd.ko` each init table sits *before* its `*_panel` struct.
- No close upstream match (best: `chongzhou,cz101b4001`, 68%); added as `dashframe,k101-frame-panel` in
  `panel-jadard-jd9365da-h3.c` (board/linux/patches).
- Timings (Allwinner convention, `hbp`/`vbp` include sync width):
  dclk 53 MHz, ht 880, hspw 20, hbp 22, vt 1328, vspw 4, vbp 14
  → DRM: hfp 58, hsync 20, hbp 2; vfp 34, vsync 4, vbp 10.
  Mainline runs the same totals at 45 MHz (~38 Hz) instead of 53 MHz: at 53 MHz the panel misses
  lines (they keep the previous frame) whenever the CPU is busy, even with pure CPU load. Not
  fixed by DRAM master priorities, a faster MBUS, a fixed CPU clock or forcing the DC-DCs into PWM
  mode; `tools/display-load-test.sh` reproduces it.
  Mainline uses hfp 40 / hsync 20 / hbp 20 (same totals): sun6i DSI cannot send a 2-pixel HBP in
  non-burst mode and the panel loses sync. Video mode must be non-burst (stock `lcd_dsi_if=0`);
  in burst mode the panel takes the init sequence but never refreshes.
- Reset: PH7 (`lcd_gpio_0`, active low). Power: `dc1sw` only (sys_config also names `eldo1`, but the stock firmware leaves it off).
- Backlight: PWM0 on PH0, 40 kHz, polarity normal, min 5%.

## Touch — Silead GSL1680

I²C0 (PH2/PH3), address 0x40, IRQ PB5, wake/enable PH1 (active-high), power `ldo_io1` 3.3 V.
1280×800 (landscape coords), no swap. sys_config inverts X and Y; with mainline and the
landscape orientation above only X must be inverted (verified by tapping corners). Firmware above.
Raw coordinates only span ~x 255..1286, y 10..640 (the vendor's closed `gsl_point_id` library did the
scaling); corrected in userspace with a libinput calibration matrix
(`board/rootfs/overlay/etc/udev/rules.d/99-dashframe-touch.rules`, fitted from 5 taps).

## Accelerometer — MiraMEMS mir3da (DA217-class)

I²C1 (PH4/PH5), address 0x27, INT1 PB7. Not needed for a fixed frame.

## Wi-Fi — RTL8188FU over USB

On USB host port `usbc1` (internal). Power/enable PL6 (`wl_reg_on`), host-wake PL7.
Mainline driver: `rtl8xxxu`.

## Other

- USB OTG (`usbc0`): ID pin PH8, VBUS via AXP.
- Audio amp enable: PH9.
- Keys: `sunxi-keyboard` (LRADC).
