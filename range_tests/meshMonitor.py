#!/usr/bin/env python3
"""
Batman-adv Mesh Network Monitor
Displays real-time status of mesh nodes, hops, and connectivity
Run with: sudo python3 meshMonitor.py
"""

import subprocess
import json
import time
import os
import sys
import logging
from datetime import datetime
from collections import defaultdict

# Configure logging
logging.basicConfig(
    level=logging.WARNING,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler('mesh_monitor.log')]
)

# Configuration
MESH_INTERFACE = 'bat0'
REFRESH_INTERVAL = 5  # seconds
TIMEOUT = 10  # seconds for batctl commands


class MeshMonitor:
    def __init__(self, mesh_interface=MESH_INTERFACE):
        self.mesh_interface = mesh_interface
        self.neighbors = {}
        self.originators = {}
        self.direct_neighbors = set()
        
    def get_originators(self):
        """Get batman-adv originators using JSON output."""
        try:
            result = subprocess.check_output(
                ['sudo', 'batctl', 'meshif', self.mesh_interface, 'originators', 'json'],
                stderr=subprocess.STDOUT,
                timeout=TIMEOUT
            ).decode()
            data = json.loads(result)
            return data.get('originators', {})
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError) as e:
            logging.error(f"Error getting originators: {e}")
            return {}
    
    def get_neighbors(self):
        """Get batman-adv neighbors using JSON output."""
        try:
            result = subprocess.check_output(
                ['sudo', 'batctl', 'meshif', self.mesh_interface, 'neighbors', 'json'],
                stderr=subprocess.STDOUT,
                timeout=TIMEOUT
            ).decode()
            data = json.loads(result)
            return data.get('neighbors', [])
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError) as e:
            logging.error(f"Error getting neighbors: {e}")
            return []
    
    def get_gateway_info(self):
        """Get current gateway info."""
        try:
            result = subprocess.check_output(
                ['sudo', 'batctl', 'meshif', self.mesh_interface, 'gw_mode'],
                stderr=subprocess.STDOUT,
                timeout=TIMEOUT
            ).decode()
            return result.strip()
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            logging.error(f"Error getting gateway info: {e}")
            return "Unknown"
    
    def parse_data(self):
        """Parse batman-adv data and calculate statistics."""
        originators = self.get_originators()
        neighbors_list = self.get_neighbors()
        
        # Count direct neighbors
        self.direct_neighbors = set()
        hop_count = defaultdict(int)
        
        for neighbor in neighbors_list:
            neighbor_addr = neighbor.get('address', '')
            if neighbor_addr:
                self.direct_neighbors.add(neighbor_addr)
        
        # Count hops to each originator
        for orig_addr, orig_data in originators.items():
            neighbors = orig_data.get('neighbors', [])
            best_metric = float('inf')
            
            for neighbor in neighbors:
                metric = neighbor.get('metric', float('inf'))
                if metric < best_metric:
                    best_metric = metric
                    best_via = neighbor.get('address', '')
            
            # Estimate hops based on metric
            if best_metric >= 256:
                hops = 1
            elif best_metric >= 128:
                hops = 2
            else:
                hops = 3
            
            hop_count[orig_addr] = hops
        
        return {
            'originators': originators,
            'neighbors': neighbors_list,
            'direct_neighbors': self.direct_neighbors,
            'hop_count': hop_count
        }
    
    def clear_screen(self):
        """Clear terminal screen."""
        os.system('clear' if os.name != 'nt' else 'cls')
    
    def display_status(self, data):
        """Display formatted mesh status."""
        self.clear_screen()
        
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        originators = data['originators']
        neighbors = data['neighbors']
        direct_neighbors = data['direct_neighbors']
        hop_count = data['hop_count']
        
        print(f"\n{'='*80}")
        print(f"Batman-adv Mesh Monitor - {timestamp}")
        print(f"Interface: {self.mesh_interface}")
        print(f"Gateway Mode: {self.get_gateway_info()}")
        print(f"{'='*80}\n")
        
        # Summary stats
        total_neighbors = len(neighbors)
        total_originators = len(originators)
        
        print(f"📊 SUMMARY")
        print(f"  Direct Neighbors (Hop 1):  {len(direct_neighbors)}")
        print(f"  Total Reachable Nodes:     {total_originators}")
        print(f"  Total Neighbors:           {total_neighbors}\n")
        
        # Direct neighbors (hop 1)
        if direct_neighbors:
            print(f"🔗 DIRECT NEIGHBORS (Hop 1)")
            print(f"  {'-'*76}")
            for addr in sorted(direct_neighbors):
                print(f"    {addr}")
            print()
        
        # Multi-hop nodes
        multihop_2 = {addr: hops for addr, hops in hop_count.items() if hops == 2}
        multihop_3plus = {addr: hops for addr, hops in hop_count.items() if hops >= 3}
        
        if multihop_2:
            print(f"🌉 2-HOP NODES")
            print(f"  {'-'*76}")
            for addr in sorted(multihop_2.keys()):
                print(f"    {addr} (2 hops)")
            print()
        
        if multihop_3plus:
            print(f"📡 3+ HOP NODES")
            print(f"  {'-'*76}")
            for addr, hops in sorted(multihop_3plus.items()):
                print(f"    {addr} ({hops} hops)")
            print()
        
        # Detailed neighbor info
        if neighbors:
            print(f"📋 NEIGHBOR DETAILS")
            print(f"  {'-'*76}")
            print(f"  {'Address':<20} {'Hardif':<15} {'Metric':<15} {'TQ':<10}")
            print(f"  {'-'*76}")
            for neighbor in neighbors:
                addr = neighbor.get('address', 'N/A')
                hardif = neighbor.get('hardif', 'N/A')
                metric = neighbor.get('metric', 'N/A')
                tq = neighbor.get('throughput', 'N/A')
                print(f"  {addr:<20} {hardif:<15} {str(metric):<15} {str(tq):<10}")
            print()
        
        print(f"{'='*80}")
        print(f"Updating in {REFRESH_INTERVAL} seconds... (Press Ctrl+C to exit)\n")
    
    def run(self):
        """Main monitoring loop."""
        try:
            while True:
                data = self.parse_data()
                self.display_status(data)
                time.sleep(REFRESH_INTERVAL)
        except KeyboardInterrupt:
            print("\n\n[*] Mesh monitor stopped.")
        except Exception as e:
            print(f"\n\n[ERROR] Unexpected error: {e}")
            logging.error(f"Unexpected error: {e}")


if __name__ == "__main__":
    if os.geteuid() != 0:
        print("Error: This script must be run with sudo")
        sys.exit(1)
    
    monitor = MeshMonitor()
    monitor.run()
