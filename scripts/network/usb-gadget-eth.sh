#!/bin/bash
# Enhanced USB Ethernet Gadget with Windows RNDIS Auto-detection
# Location: /usr/local/bin/usb-gadget-eth.sh

set -e

# Load required kernel module
modprobe libcomposite

cd /sys/kernel/config/usb_gadget/

# Create gadget
G="travelrouter"
mkdir -p "$G"
cd "$G"

# USB device descriptors
echo 0x1d6b > idVendor    # Linux Foundation
echo 0x0104 > idProduct   # Multifunction Composite Gadget
echo 0x0100 > bcdDevice   # Device version
echo 0x0200 > bcdUSB      # USB 2.0

# Device strings
mkdir -p strings/0x409
echo "fedcba9876543210" > strings/0x409/serialnumber
echo "TravelRouter" > strings/0x409/manufacturer
echo "USB Ethernet/RNDIS Gadget" > strings/0x409/product

# Create configuration
mkdir -p configs/c.1
mkdir -p configs/c.1/strings/0x409
echo "RNDIS" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower  # 250mA

# Create RNDIS function
mkdir -p functions/rndis.usb0

# CRITICAL: Set host MAC and device MAC
# Using locally administered MAC addresses (bit 1 of first byte set)
echo "02:00:00:00:00:01" > functions/rndis.usb0/host_addr
echo "02:00:00:00:00:02" > functions/rndis.usb0/dev_addr

# Link function to configuration
ln -s functions/rndis.usb0 configs/c.1/

# Microsoft OS Descriptors (tells Windows this is RNDIS)
mkdir -p os_desc
echo 1 > os_desc/use
echo 0xcd > os_desc/b_vendor_code
echo MSFT100 > os_desc/qw_sign

# Link config to OS descriptors
ln -s configs/c.1 os_desc/

# Enable the gadget
UDC=$(ls /sys/class/udc | head -n1)
echo "$UDC" > UDC

echo "USB Ethernet gadget configured: $UDC"
