setenv bootargs console=ttyO0,115200n8 root=/dev/mmcblk0p2
fatload mmc 0:1 0x80000000 /uImage
fatload mmc 0:1 0x81000000 /initramfs
fatload mmc 0:1 0x82000000 /dtb
bootm 0x80000000 0x81000000 0x82000000
