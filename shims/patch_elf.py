#!/usr/bin/env python3
import sys
import os

def patch_elf(filename, old_lib, new_lib):
    if len(old_lib) != len(new_lib):
        raise ValueError("Library names must be of the same length")
    
    if not os.path.exists(filename):
        print(f"Error: {filename} does not exist")
        return False
        
    with open(filename, 'rb') as f:
        data = bytearray(f.read())
    
    old_bytes = old_lib.encode('ascii') + b'\x00'
    new_bytes = new_lib.encode('ascii') + b'\x00'
    
    idx = 0
    count = 0
    while True:
        idx = data.find(old_bytes, idx)
        if idx == -1:
            break
        data[idx:idx+len(old_bytes)] = new_bytes
        idx += len(old_bytes)
        count += 1
        
    if count == 0:
        print(f"Warning: {old_lib} not found in {filename}")
        return False
    else:
        print(f"Patched {count} occurrences of {old_lib} to {new_lib} in {filename}")
        with open(filename, 'wb') as f:
            f.write(data)
        return True

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: patch_elf.py <file> <old_lib> <new_lib>")
        sys.exit(1)
    patch_elf(sys.argv[1], sys.argv[2], sys.argv[3])
