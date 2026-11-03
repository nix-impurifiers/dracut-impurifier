# SPDX-License-Identifier: MIT
"""Boot the actual generated initramfs with no root disk or shared host store."""
import subprocess
import sys

try:
    result = subprocess.run([
        'qemu-system-x86_64', '-machine', 'accel=tcg', '-m', '512',
        '-nodefaults', '-nographic', '-serial', 'stdio', '-no-reboot',
        '-kernel', sys.argv[1], '-initrd', sys.argv[2],
        '-append', 'console=ttyS0 root=/dev/nonexistent panic=-1 rd.retry=5 rd.shell=0',
    ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
except subprocess.TimeoutExpired as error:
    captured = error.stdout or b''
    print(captured.decode(errors='replace') if isinstance(captured, bytes) else captured)
    raise SystemExit('guest failed to power off within 90 seconds')
print(result.stdout)
if result.returncode or sys.argv[3] not in result.stdout:
    raise SystemExit('early-userspace proof did not execute')
