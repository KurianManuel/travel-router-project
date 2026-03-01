# TravelRouter - First Time Setup Guide

Quick 2-minute setup for Windows PCs. Only needed once per computer.

---

## What You Need

- Your TravelRouter (Raspberry Pi)
- USB cable (USB-C or Micro-USB depending on your Pi model)
- Windows PC

---

## Setup Steps

### Step 1: Install Driver (One-Time, 30 seconds)

**Option A - Using INF File (Recommended):**

1. Download the driver file: `travelrouter-usb-driver.inf`
2. Right-click the INF file
3. Select **"Install"**
4. Click **"Yes"** when Windows asks for permission
5. Done! You'll see a confirmation message.

**Option B - Manual Driver Selection:**

1. Plug in the TravelRouter
2. Open **Device Manager** (press Windows key + X, select Device Manager)
3. Find **"RNDIS"** (it will have a yellow warning icon)
4. Right-click → **"Update driver"**
5. Select **"Browse my computer for drivers"**
6. Select **"Let me pick from a list of available drivers on my computer"**
7. Choose category: **"Network adapters"**
8. Manufacturer: **"Microsoft"**
9. Model: **"Remote NDIS Compatible Device"**
10. Click **"Next"** → Ignore any warnings → Click **"Yes"**

### Step 2: Connect & Test

1. **Plug in** the TravelRouter via USB
2. **Wait 10-15 seconds** for Windows to configure
3. Look for a new network connection in the system tray
4. Open browser and go to: **http://192.168.7.1**
5. **Login** with password: `admin123`

**That's it!** 🎉

---

## Troubleshooting

### "I don't see RNDIS in Device Manager"

- The device might appear under **"Other devices"** or **"Ports"**
- Look for anything with "USB" in the name
- Follow Option B steps anyway - it will work

### "Network shows 'No Internet'"

- This is normal! The TravelRouter provides internet through the Pi
- Open http://192.168.7.1 to configure WiFi

### "Cannot access 192.168.7.1"

Check your PC's IP address:
1. Open Command Prompt (cmd)
2. Type: `ipconfig`
3. Look for **"Ethernet adapter"** with USB in the name
4. Should show: `192.168.7.2`
5. If not, disconnect and reconnect the Pi

### "Driver installation failed"

- Make sure you're running as Administrator
- Try restarting your PC and trying again
- Use Option B (manual selection) instead

---

## Network Configuration

After connecting to http://192.168.7.1:

1. **Dashboard** shows VPN status and WiFi connection
2. **WiFi Manager** - scan and connect to available networks
3. **Power** menu - shutdown or reboot the Pi

The TravelRouter will:
- Connect to your selected WiFi network
- Route all traffic through a secure VPN
- Provide internet to your PC via USB

---

## Important Notes

✅ **After first setup:** Future connections are automatic - just plug and go!

✅ **Each new PC:** Needs this one-time setup

✅ **Same PC:** Works automatically after first setup

🔒 **Security:** All traffic goes through encrypted VPN tunnel

⚡ **Speed:** Limited by USB 2.0 (~100 Mbps theoretical)

---

## Need Help?

- Check Device Manager for driver status
- Verify Pi is powered (look for LED activity)
- Try a different USB cable or port
- Restart both PC and Pi

---

**Version 1.0** | Last updated: February 2026
