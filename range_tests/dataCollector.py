import csv
import time
import subprocess
from datetime import datetime
import os
import serial
import pynmea2
import iperf3
import iwlib
import logging
import re
import socket

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('data_collector.log'),
        logging.StreamHandler()
    ]
)

GPSSerialPort = '/dev/ttyUSB0'  # GPS Serial Port
gpsBaudrate = 9600

HaLowInterface = 'wlan0'  # HaLow Network Interface
MeshInterface = 'bat0'  # Batman-adv mesh interface

# list of possible iperf3 servers
#iperf3Servers = ['192.168.10.2', '192.168.10.3', '192.168.10.4', '192.168.10.5']
iperf3Servers = ['192.168.10.3', '192.168.10.4', '192.168.10.5']

currentDate = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
csvFilePath = f'data_log_{currentDate}.csv'  # CSV file path


def get_gps_data(serial_port=GPSSerialPort, baudrate=gpsBaudrate, timeout=5):
    """Read GPS data from serial port and return parsed NMEA data."""
    ser = None
    try:
        ser = serial.serialposix.Serial(serial_port, baudrate, timeout=timeout)
        max_attempts = 10
        attempts = 0
        
        while attempts < max_attempts:
            line = ser.readline().decode('ascii', errors='replace')
            if line.startswith('$GPGGA'):
                msg = pynmea2.parse(line)
                return (
                    msg.latitude,
                    msg.longitude,
                    msg.altitude,
                    msg.timestamp,
                    msg.lat_dir,
                    msg.lon_dir,
                    msg.altitude_units
                )
            attempts += 1
            
        logging.warning("No valid GPS data received after maximum attempts")
        return None, None, None, None, None, None, None
        
    except pynmea2.ParseError as e:
        logging.error(f"NMEA parse error: {e}")
        return None, None, None, None, None, None, None
    finally:
        if ser and ser.is_open:
            ser.close()


def get_halow_info_iwlib(interface=HaLowInterface):
    """Get HaLow network info using iwlib library."""
    try:
        wifi = iwlib.get_iwconfig(interface)
        bitrate = wifi.get('BitRate', None)
        stats = wifi.get('stats', {})

        level = stats.get('level', 0)
        quality = stats.get('quality', 0)
        essid = wifi.get('ESSID', None)

        # Convert level to dBm
        if level > 64:
            rssi_dbm = level - 256
        else:
            rssi_dbm = level

        return {
            'signal_level_dbm': rssi_dbm,
            'link_quality': quality,
            'essid': essid,
            'bitrate': bitrate
        }

    except Exception as e:
        logging.error(f"Error getting HaLow info: {e}")
        return None


def get_halow_info_iwconfig(interface=HaLowInterface):
    """Get HaLow network info using iwconfig command (fallback)."""
    try:
        result = subprocess.check_output(
            ['iwconfig', interface],
            stderr=subprocess.STDOUT,
            timeout=5
        ).decode()
        
        # Extract signal level and link quality using regex
        quality_match = re.search(r"Link Quality=(\d+)/(\d+)", result)
        signal_match = re.search(r"Signal level=(-?\d+) dBm", result)
        essid_match = re.search(r'ESSID:"(.+?)"', result)

        info = {}
        if quality_match:
            info['link_quality'] = int(quality_match.group(1))
            info['max_quality'] = int(quality_match.group(2))
        if signal_match:
            info['signal_level_dbm'] = int(signal_match.group(1))
        if essid_match:
            info['essid'] = essid_match.group(1)

        return info if info else None

    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
        logging.error(f"Error running iwconfig: {e}")
        return None


def get_batman_traceroute(ipAddress, mesh_interface=MeshInterface):
    """Get batman-adv traceroute to target IP."""
    try:
        result = subprocess.check_output(
            ['sudo', 'batctl', 'meshif', mesh_interface, 'traceroute', ipAddress],
            stderr=subprocess.STDOUT,
            timeout=10
        ).decode()
        return result.strip()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
        logging.error(f"Error getting batman traceroute for {ipAddress}: {e}")
        return None




def open_csv(file_path):
    """Open CSV file and write header if new file."""
    file_exists = os.path.isfile(file_path)
    csv_file = open(file_path, mode='a', newline='')
    csv_writer = csv.writer(csv_file)

    if not file_exists:
        header = [
            'Timestamp', 'Latitude', 'Longitude', 'Altitude',
            'Signal_Level_dBm', 'Link_Quality', 'ESSID', 'Target_Server',
            'Transfer', 'Bitrate', 'Jitter_MS', 'Lost_Packets', 'Total_Packets', 'BATMAN_Trace'
        ]
        csv_writer.writerow(header)
        logging.info(f"Created new CSV file: {file_path}")

    return csv_file, csv_writer


def run_iperf3_test(test_server, port=5201, duration=10, bandwidth=1000000):
    """Run iperf3 test with timeout and graceful error handling."""
    try:
        client = iperf3.Client()
        client.server_hostname = test_server
        client.port = port
        client.duration = duration
        client.protocol = 'udp'
        client.reverse = False
        client.bandwidth = bandwidth
        client.connect_timeout = 5  # Connection timeout
        
        logging.debug(f"Starting iperf3 test to {test_server}...")
        result = client.run()
        
        if result.error:
            logging.error(f"Iperf3 error for {test_server}: {result.error}")
            return None, None, None, None, None
        
        if client.protocol == 'udp':
            return (
                result.Mbps,
                result.bps,
                result.jitter_ms,
                result.lost_packets,
                result.packets
            )
        return None, None, None, None, None

    except socket.timeout:
        logging.error(f"Socket timeout connecting to {test_server}:{port}")
        return None, None, None, None, None
    except ConnectionRefusedError:
        logging.error(f"Connection refused by {test_server}:{port} - server not responding")
        return None, None, None, None, None
    except OSError as e:
        logging.error(f"Network error for {test_server}: {e}")
        return None, None, None, None, None
    except Exception as e:
        logging.error(f"Unexpected error in iperf3 test for {test_server}: {type(e).__name__}: {e}")
        return None, None, None, None, None


def main():
    logging.info("Starting data collection...")
    
    csv_file, csv_writer = open_csv(csvFilePath)

    try:
        while True:
            for server in iperf3Servers:
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                logging.info(f"[{timestamp}] Testing server {server}...")

                try:
                    # Get GPS data with timeout
                    latitude, longitude, altitude, gpsTime, latitudeDir, longitudeDir, altitudeUnits = get_gps_data()
                    
                    # Get HaLow network info with fallback
                    halow_info = get_halow_info_iwlib()
                    if not halow_info:
                        halow_info = get_halow_info_iwconfig()
                    
                    if halow_info:
                        signal_level_dbm = halow_info.get('signal_level_dbm', None)
                        link_quality = halow_info.get('link_quality', None)
                        essid = halow_info.get('essid', None)
                    else:
                        signal_level_dbm = None
                        link_quality = None
                        essid = None

                    # Run iperf3 test with timeout protection
                    iperf_Mbps, iperf_bps, iperf_jitter, iperf_lostpackets, iperf_packages = run_iperf3_test(server)

                    # Get batman traceroute
                    batman_trace = get_batman_traceroute(server)

                    # Write row to CSV
                    row = [
                        timestamp, latitude, longitude, altitude,
                        signal_level_dbm, link_quality, essid, server,
                        iperf_Mbps, iperf_bps, iperf_jitter, iperf_lostpackets, iperf_packages, batman_trace
                    ]
                    csv_writer.writerow(row)
                    csv_file.flush()
                    
                    if iperf_Mbps is not None:
                        logging.info(f"Server={server}, RSSI={signal_level_dbm}dBm, Transfer={iperf_Mbps}Mbps, Jitter={iperf_jitter}ms, Lost={iperf_lostpackets}/{iperf_packages}")
                    else:
                        logging.warning(f"Server {server} - no iperf3 response")

                except Exception as e:
                    logging.error(f"Error testing {server}: {type(e).__name__}: {e}")
                    continue

                time.sleep(5)  # Delay between tests to prevent overwhelming network

            logging.info(f"Completed round of tests. Waiting 30 seconds before next round...")
            time.sleep(30)

    except KeyboardInterrupt:
        logging.info("Stopping data collection.")
    except Exception as e:
        logging.error(f"Unexpected error in main loop: {e}")
    finally:
        csv_file.close()
        logging.info("CSV file closed. Exiting.")


if __name__ == "__main__":
    main()