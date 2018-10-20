#ifndef HOST_H
#define HOST_H

#define HOSTBASE 0xFFFFFF40
#define HW_HOST(x) *(volatile unsigned int *)(HOSTBASE+x)

/* SPI registers */

/* DIP switches, bits 9 downto 0 */
#define HW_HOST_SW 0x0

#define HW_HOST_SWB_SCANLINES 1
#define HW_HOST_SWF_SCANLINES 2

#define HW_HOST_SWF_BITFLIP 4

#define HW_HOST_SWB_MULTITAP 4
#define HW_HOST_SWF_MULTITAP 16

/* Control the host:
 *  Bit 0: 1=> Reset, 0=> Run
 *  Bit 1: 1=> Inhibit, 0=> Run
 *  Bit 2: 1=> Ctrl owns SD card, 0=> Host owns SD card
*/
#define HW_HOST_CTRL 0x04
#define HW_HOST_CTRLF_RESET 1
#define HW_HOST_CTRLF_BOOTDONE 2
#define HW_HOST_CTRLF_SDCARD 4
#define HW_HOST_CTRLF_KEYBOARD 8

/* Boot data.
   Blocks until the previous byte has been read,
   so it's safe to just deluge this register with data. */
#define HW_HOST_BOOTDATA 0x08

#define HW_HOST_MOUSEBUTTONS 0x0c	/* RW */
#define HW_HOST_MOUSE 0x10
#define HW_HOST_MOUSEF_IDLE 0x1  /* Has the previously written event been received? */
#define HW_HOST_VOLUMES 0x14 /* Each volume control is 3 bits: 2:0, 6:4, 10:8, 14:12 */
#define HW_HOST_GAMEPAD 0x18

#define HW_HOST_ROMMAPPING 0x1c
#define HW_HOST_ROMMAPPING_NONE 0
#define HW_HOST_ROMMAPPING_384 1
#define HW_HOST_ROMMAPPING_768 2

#endif

