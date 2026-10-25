# X5SA Happy-Hare v3 Configuration Reference
## Complete Migration Data for v3 → v4 Upgrade

**Generated:** 2026-10-14  
**Source:** X5SA (192.168.80.53) live configuration  
**MMU:** ERCF v2.0 (8 gates)  
**Hotend:** HeroMe Gen7 (Volcano)  
**Probe:** BTT Eddy NG  
**Happy-Hare Version:** 3.42  
**Klipper:** v0.13.0-658-gbd09e0170  

---

## 🔌 MCU & Pin Configuration

### MMU MCU (BTT MMB11) - CANbus
CANbus UUID: ce0800926f16

### Pin Aliases (mmu.cfg -> board_pins mmu)
MMU_GEAR_UART    = PC6
MMU_GEAR_STEP    = PD0
MMU_GEAR_DIR     = PD3
MMU_GEAR_ENABLE  = PA15
MMU_GEAR_DIAG    = PA3
MMU_SEL_UART     = PC7
MMU_SEL_STEP     = PD2
MMU_SEL_DIR      = PB13
MMU_SEL_ENABLE   = PD1
MMU_SEL_DIAG     = PA4
MMU_SEL_ENDSTOP  = PB2
MMU_SEL_SERVO    = PA0
MMU_ENCODER      = PA1
MMU_GATE_SENSOR  = (shared, not assigned)
MMU_NEOPIXEL     = PA2
MMU_PRE_GATE_0   = PB9
MMU_PRE_GATE_1   = PA8
MMU_PRE_GATE_2   = PC15
MMU_PRE_GATE_3   = PC13
MMU_PRE_GATE_4   = PC14
MMU_PRE_GATE_5   = PB12
MMU_PRE_GATE_6   = PB11
MMU_PRE_GATE_7   = PB10
MMU_POST_GATE_0-11 = (empty)
MMU_ESPOOLER_* = (empty)

### Toolhead MCU (BTT EBB42 CANbus)
extruder_switch_pin: ^EBBCan:PB7
toolhead_switch_pin: ^EBBCan:PB5

### EREC Cutter Servo
Pin: PB6 (PROBE port on Octopus Pro mainboard)

### Eddy NG Probe
MCU CANbus UUID: 78bffca13e4f
I2C Bus: i2c0f on eddy MCU
X_OFFSET: -48.2
Y_OFFSET: 0
TAP_TARGET_Z: -0.95

---

## ⚙️ Stepper Configurations

### Gear Stepper (TMC2209)
run_current: 0.9A
hold_current: 0.4A
stealthchop_threshold: 0 (spreadCycle)
diag_pin: ^mmu:PA3
driver_SGTHRS: 60
sense_resistor: 0.110
interpolate: True
rotation_distance: 22.7316868 (calibrated per gate, see below)
gear_ratio: 80:20
microsteps: 16
full_steps_per_rotation: 200

### Selector Stepper (TMC2209)
run_current: 0.8A
hold_current: 0.3A
stealthchop_threshold: 100
diag_pin: ^mmu:PA4
driver_SGTHRS: 75
sense_resistor: 0.110
interpolate: True
rotation_distance: 40
gear_ratio: 1:1
microsteps: 16
full_steps_per_rotation: 200
endstop_pin: ^mmu:PB2 (physical microswitch)

---

## 🎯 Servo Configurations

### Selector Servo (MG90S/SAVOX)
servo_up_angle: 30°
servo_down_angle: 100°
servo_move_angle: 50°
servo_duration: 0.4s
servo_dwell: 0.5s
servo_always_active: 1
servo_active_down: 0
servo_buzz_gear_on_down: 1

### EREC Cutter Servo
closed_angle: 70°
open_angle: 10°
duration: 1.5s
idle_time: 1.8s

---

## 📏 Critical Dimensions

### Toolhead (HeroMe Gen7)
toolhead_extruder_to_nozzle: 72mm
toolhead_ooze_reduction: 2.5mm (PETG)
toolhead_extruder_to_nozzle: 99.2mm (from mmu_parameters.cfg)

### Bowden
bowden_homing_max: 2000mm
bowden_apply_correction: 0 (disabled)
bowden_allowable_load_delta: 20mm
bowden_pre_unload_test: 1
bowden_pre_unload_error_tolerance: 50%

### Gate Parking
gate_homing_endstop: encoder
gate_homing_max: 70mm
gate_parking_distance: 13mm
gate_preload_homing_max: 300mm
gate_preload_parking_distance: -10mm
gate_endstop_to_encoder: 10mm
gate_unload_buffer: 50mm
gate_load_retries: 2
gate_autoload: 1
gate_final_eject_distance: 0

### Extruder Homing
extruder_homing_max: 80mm
extruder_homing_endstop: collision
extruder_homing_buffer: 25mm
extruder_collision_homing_current: 30%
extruder_force_homing: 0

### Toolhead Homing
toolhead_homing_max: 140mm

---

## 🚀 Speeds & Accelerations

### Gear Stepper
gear_from_spool_speed: 80mm/s @ 100mm/s²
gear_from_buffer_speed: 150mm/s @ 400mm/s²
gear_unload_speed: 80mm/s @ 100mm/s²
gear_short_move_speed: 80mm/s @ 600mm/s²
gear_short_move_threshold: 70mm
gear_homing_speed: 50mm/s

### Extruder
extruder_load_speed: 16mm/s
extruder_unload_speed: 16mm/s
extruder_sync_load_speed: 18mm/s
extruder_sync_unload_speed: 18mm/s
extruder_homing_speed: 18mm/s

### Selector
selector_move_speed: 200mm/s
selector_homing_speed: 60mm/s
selector_touch_speed: 80mm/s
selector_touch_enabled: 0

### Hardware Limits
gear_max_velocity: 300mm/s
gear_max_accel: 1500mm/s²
selector_max_velocity: 250mm/s
selector_max_accel: 1200mm/s²

---

## 🔄 Sync Feedback (Proportional Sensor)
sync_feedback_enabled: 1
sync_feedback_buffer_range: 14.2mm
sync_feedback_buffer_maxrange: 14.2mm
sync_feedback_speed_multiplier: 5
sync_feedback_boost_multiplier: 3
sync_feedback_extrude_threshold: 5
sync_feedback_debug_log: 0

# Analog sensor calibration
sync_feedback_analog_pin: mcu:PF7
sync_feedback_analog_max_compression: 0.0315
sync_feedback_analog_max_tension: 0.9999
sync_feedback_analog_neutral_point: 0.5157

### FlowGuard
flowguard_enabled: 1
flowguard_max_relief: 40mm
flowguard_encoder_mode: 2 (auto length)
flowguard_encoder_max_motion: 15.3

---

## 🧵 Tip Forming (Form Tip - not Cut Tip)
form_tip_macro: _MMU_FORM_TIP
form_tip_current: 100%

FORM_TIP_VARS:
  ramming_volume: 0 (slicer handles it)
  ramming_volume_standalone: 0
  toolchange_temp: 0 (no change)
  toolchange_fan_assist: False
  unloading_speed_start: 80mm/s
  unloading_speed: 18mm/s
  
  cooling_tube_position: 32mm
  cooling_tube_length: 22mm
  initial_cooling_speed: 15mm/s
  final_cooling_speed: 40mm/s
  cooling_moves: 3
  
  use_skinnydip: True
  skinnydip_distance: 50mm
  dip_insertion_speed: 30mm/s
  dip_extraction_speed: 70mm/s
  melt_zone_pause: 0
  cooling_zone_pause: 0
  use_fast_skinnydip: False
  
  parking_distance: 0
  extruder_eject_speed: 25mm/s

### Parking (Toolchange)
park_toolchange: -999, -999, 1, 5, 2
park_runout: -999, -999, 1, 5, 2
park_pause: 50, 50, 5, 0, 2
park_cancel: -999, -999, 10, 0, 5
park_complete: 50, 50, 10, 0, 5

restore_xy_pos: last
travel_speed: 200mm/s
lift_speed: 15mm/s
retract_speed: 30mm/s
unretract_speed: 30mm/s

---

## 🎨 Filament Map (8 Gates)

| Gate | Material | Color (hex) | Name | SpoolID | Temp | Status |
|------|----------|-------------|------|---------|------|--------|
| 0 | PETG | faf200ff | PTG Gelb | -1 | 200 | -1 (empty) |
| 1 | PLA | dab48e | PLA Bone White | 32 | 215 | 1 (loaded) |
| 2 | PLA | cccac9 | PLA Marble Grey | 61 | 200 | 1 (loaded) |
| 3 | ABS | 000000 | ABS+ Black | 64 | 250 | 1 (loaded) |
| 4 | PETG | a47227 | PETG Gold Metallic | 41 | 250 | 1 (loaded) |
| 5 | PETG | fa0000 | PETG Neon Red | 40 | 250 | 1 (loaded) |
| 6 | ABS | 080808 | ABS Black | 69 | 260 | 0 (unknown) |
| 7 | PLA | dab48e | PLA Bone White | -1 | 200 | 0 (unknown) |

### Tool-to-Gate Map (1:1)
tool_to_gate_map: [0,1,2,3,4,5,6,7]
endless_spool_groups: [0,1,2,3,4,5,6,7]

---

## 📊 Calibration Values (Live from variables.cfg)

# Bowden Lengths (mm)
bowden_lengths: [802.1, 802.1, 802.1, 802.1, 802.1, 802.1, 802.1, 802.1]

# Gear Rotation Distances (mm)
gear_rotation_distances: [22.403, 22.6516, 22.605, 22.6316, 22.2741, 22.7847, 22.4228, 22.382]

# Selector Offsets (mm)
selector_offsets: [2.3, 25.5, 47.9, 71.1, 94.3, 117.5, 139.9, 164.5]
selector_bypass: 178.3

# Encoder
encoder_resolution: 1.0556

# Servo Angles
servo_angles: {down: 85, up: 25, move: 42}

---

## 🔧 Feature Flags & Advanced Settings

### MMU Machine
num_gates: 8
mmu_vendor: ERCF
mmu_version: 2.0
homing_extruder: 1

### Logging
log_level: 1
log_file_level: 2
log_statistics: 1
log_visual: 1
log_startup_status: 1
log_m117_messages: 1

### Endless Spool
endless_spool_enabled: 1
endless_spool_on_load: 0
endless_spool_eject_gate: -1
endless_spool_groups: [0,1,2,3,4,5,6,7]

### Spoolman
spoolman_support: push
pending_spool_id_timeout: 20
t_macro_color: allgates

### Auto-Calibration
autocal_bowden_length: 1
autotune_bowden_length: 1
skip_cal_rotation_distance: 0
autotune_rotation_distance: 0
skip_cal_encoder: 0
autotune_encoder: 0

### Clog Detection
encoder_move_validation: 1
encoder_validation: 1
flowguard_encoder_mode: 2 (auto)

### Filament Buffer & Autoload
has_filament_buffer: 1
bypass_autoload: 1
gate_autoload: 1
preload_attempts: 5
filament_recovery_on_pause: 1
retry_tool_change_on_error: 0

### Klipper Tuning
update_trsync: 0
canbus_comms_retries: 3
update_bit_max_time: 1
update_aht10_commands: 0

### Macro Overrides
pause_macro: PAUSE
action_changed_macro: _MMU_ACTION_CHANGED
print_state_changed_macro: _MMU_PRINT_STATE_CHANGED
mmu_event_macro: _MMU_EVENT
pre_unload_macro: _MMU_PRE_UNLOAD
post_form_tip_macro: _MMU_POST_FORM_TIP
post_unload_macro: _MMU_POST_UNLOAD
pre_load_macro: _MMU_PRE_LOAD
post_load_macro: _MMU_POST_LOAD

---

## 🛠️ EREC Cutter
feed_length: 48mm
cut_length: 10mm
cut_attempts: 1
post_unload_extension: EREC_CUTTER_ACTION

### Cutter Variables
variable_blade_pos: 37.5mm
variable_retract_length: 32.5mm
variable_simple_tip_forming: True
variable_cut_axis: x
variable_pin_loc_xy: 14, 250
variable_pin_park_dist: 5.0mm
variable_pin_loc_compressed_xy: 0.5, 250
variable_rip_length: 1.0mm
variable_rip_speed: 3mm/s
variable_pushback_length: 15.0mm
variable_pushback_dwell_time: 0
variable_travel_speed: 150mm/s
variable_cut_fast_move_speed: 32mm/s
variable_cut_slow_move_speed: 8mm/s
variable_evacuate_speed: 150mm/s
variable_cut_dwell_time: 50ms
variable_cut_fast_move_fraction: 1.0
variable_extruder_move_speed: 25mm/s
variable_safe_margin_xy: 30, 30
variable_gantry_servo_enabled: False

---

## 🎨 LED Configuration
neopixel_pin: mmu:PA2
chain_count: 18
color_order: GRBW

unit0:
  exit_leds: neopixel:mmu_leds (1-8)
  enabled: True
  animation: True
  exit_effect: gate_status
  entry_effect: filament_color
  status_effect: filament_color
  logo_effect: (0, 0, 0.3)

---

## 📋 Bed Mesh (Eddy NG)
horizontal_move_z: 2.2mm
speed: 150mm/s
mesh_min: 20, 20
mesh_max: 280, 275
probe_count: 9, 9
algorithm: bicubic
scan_overshoot: 8
mesh_pps: 3, 3
fade_start: 1.5
fade_end: 10
adaptive_margin: 3

---

## 📋 Migration Command Checklist

bash commands here...
(see full doc for complete checklist)

---

## 📁 Files Included in This Reference

mmu_hardware.cfg, mmu.cfg, mmu_parameters.cfg, mmu_macro_vars.cfg, mmu_sequence.cfg, variables.cfg, x5sa-ercf-migration-values.md

---

## 🔄 Rollback Procedure

If v4 upgrade fails:
./install.sh -d
cp -a ~/printer_data/config/mmu.V3 ~/printer_data/config/mmu
./install.sh -b v3
sudo systemctl restart klipper

---

**End of Reference Document**
