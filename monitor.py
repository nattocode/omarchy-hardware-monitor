#!/usr/bin/env python3
"""Small data bridge for the Hardware Monitor shell panel."""
import json
import os
from pathlib import Path
import signal
import sys
import time

PROC = Path('/proc')

def text(path, limit=65536):
    try:
        with open(path, 'rb') as file:
            return file.read(limit).decode('utf-8', 'replace')
    except (OSError, ValueError):
        return ''

def cpu_total():
    parts = text(PROC / 'stat').splitlines()[0].split()[1:]
    values = [int(value) for value in parts]
    return sum(values), values[3] + values[4]

def memory():
    values = {}
    for line in text(PROC / 'meminfo').splitlines():
        key, _, rest = line.partition(':')
        try: values[key] = int(rest.strip().split()[0]) * 1024
        except (ValueError, IndexError): pass
    return values

def process_rows(previous, delta_ticks, cores):
    rows, current = [], {}
    for entry in PROC.iterdir():
        if not entry.name.isdigit(): continue
        pid = int(entry.name)
        stat = text(entry / 'stat', 4096)
        close = stat.rfind(')')
        if close < 0: continue
        fields = stat[close + 2:].split()
        if len(fields) < 22: continue
        try:
            ticks = int(fields[11]) + int(fields[12])
            started = int(fields[19])
        except ValueError: continue
        current[pid] = (started, ticks)
        old = previous.get(pid)
        cpu = round(100 * cores * (ticks - old[1]) / delta_ticks, 1) if old and old[0] == started and delta_ticks > 0 and ticks >= old[1] else 0.0
        status = text(entry / 'status', 16384)
        rss = 0; uid = -1
        for line in status.splitlines():
            if line.startswith('VmRSS:'):
                try: rss = int(line.split()[1]) * 1024
                except (ValueError, IndexError): pass
            elif line.startswith('Uid:'):
                try: uid = int(line.split()[1])
                except (ValueError, IndexError): pass
        name = stat[stat.find('(') + 1:close][:80]
        command = text(entry / 'cmdline', 4096).split('\0')[0][:220] or name
        rows.append({'pid': pid, 'start': started, 'name': name, 'command': command,
                     'cpu': cpu, 'memory': rss, 'mine': uid == os.geteuid()})
    return rows, current

def disks():
    out, seen = [], set()
    for line in text(PROC / 'mounts').splitlines():
        parts = line.split()
        if len(parts) < 3: continue
        device, path, kind = parts[:3]
        path = path.replace('\\040', ' ')
        if not device.startswith('/dev/') and kind not in ('btrfs', 'zfs'): continue
        try:
            if device in seen: continue
            seen.add(device)
            info = os.statvfs(path)
            total = info.f_blocks * info.f_frsize
            free = info.f_bavail * info.f_frsize
            if total: out.append({'path': path, 'device': device[:120], 'total': total, 'used': total - free})
        except OSError: pass
    return out[:20]

def cpu_temperature():
    for zone in Path('/sys/class/thermal').glob('thermal_zone*'):
        label = text(zone / 'type', 100).strip().lower()
        if any(word in label for word in ('pkg', 'cpu', 'k10temp', 'x86')):
            try: return round(int(text(zone / 'temp', 30).strip()) / 1000, 1)
            except ValueError: pass
    return None

def cpu_frequency():
    for line in text(PROC / 'cpuinfo').splitlines():
        if line.startswith('cpu MHz'):
            try: return round(float(line.partition(':')[2]) / 1000, 2)
            except ValueError: pass
    return None

def cpu_model():
    for line in text(PROC / 'cpuinfo').splitlines():
        if line.startswith(('model name', 'Hardware')):
            return line.partition(':')[2].strip()[:120]
    return 'CPU'

def watch():
    previous = {}; total, idle = cpu_total(); cores = os.cpu_count() or 1
    model = cpu_model()
    while True:
        time.sleep(1.5)
        now, now_idle = cpu_total()
        delta = max(0, now - total)
        cpu = round(100 * (1 - (now_idle - idle) / delta), 1) if delta else 0.0
        total, idle = now, now_idle
        mem = memory()
        rows, previous = process_rows(previous, delta, cores)
        payload = {'cpu': max(0, min(cpu, 100)), 'cores': cores, 'model': model,
                   'frequency': cpu_frequency(), 'temperature': cpu_temperature(),
                   'memTotal': mem.get('MemTotal', 0), 'memUsed': max(0, mem.get('MemTotal', 0) - mem.get('MemAvailable', 0)),
                   'memAvailable': mem.get('MemAvailable', 0), 'memCached': mem.get('Cached', 0), 'memFree': mem.get('MemFree', 0),
                   'swapTotal': mem.get('SwapTotal', 0), 'swapUsed': max(0, mem.get('SwapTotal', 0) - mem.get('SwapFree', 0)),
                   'uptime': int(float(text(PROC / 'uptime').split()[0])),
                   'processes': rows[:2000], 'disks': disks()}
        print(json.dumps(payload, ensure_ascii=False, separators=(',', ':')), flush=True)

def terminate(pid_text, start_text, force):
    try:
        pid = int(pid_text); started = int(start_text)
        if pid <= 1 or pid == os.getpid(): raise ValueError('Invalid PID')
        stat = text(PROC / str(pid) / 'stat', 4096)
        close = stat.rfind(')')
        if close < 0 or int(stat[close + 2:].split()[19]) != started:
            raise ValueError('Process already exited')
        status = text(PROC / str(pid) / 'status', 16384)
        owner = next(int(line.split()[1]) for line in status.splitlines() if line.startswith('Uid:'))
        if owner != os.geteuid(): raise PermissionError('Only your processes can be ended')
        os.kill(pid, signal.SIGKILL if force else signal.SIGTERM)
        print(json.dumps({'ok': True}), flush=True)
    except (OSError, ValueError, IndexError, StopIteration) as error:
        print(json.dumps({'ok': False, 'error': str(error)[:200]}), flush=True)
        return 1
    return 0

if __name__ == '__main__':
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    if len(sys.argv) == 2 and sys.argv[1] == 'watch': watch()
    elif len(sys.argv) == 5 and sys.argv[1] == 'terminate':
        sys.exit(terminate(sys.argv[2], sys.argv[3], sys.argv[4] == 'force'))
    else:
        print('usage: monitor.py watch | terminate PID START term|force', file=sys.stderr)
        sys.exit(2)
