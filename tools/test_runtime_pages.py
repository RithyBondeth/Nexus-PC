#!/usr/bin/env python3
import struct
import unittest
from check_runtime_pages import audit

def elf(headers):
    data = bytearray(65536)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<H', data, 18, 183)
    struct.pack_into('<Q', data, 32, 64)
    struct.pack_into('<HH', data, 54, 56, len(headers))
    for i, h in enumerate(headers):
        struct.pack_into('<IIQQQQQQ', data, 64 + 56 * i, *h)
    return data

class PageAuditTests(unittest.TestCase):
    def test_reject_4k_load(self):
        with self.assertRaisesRegex(ValueError, 'aligned'):
            audit(elf([(1, 5, 0, 0, 0, 100, 100, 4096)]))
    def test_reject_offset_congruence(self):
        with self.assertRaisesRegex(ValueError, 'aligned'):
            audit(elf([(1, 5, 4096, 0, 0, 100, 100, 16384)]))
    def test_reject_relro_writable_collision(self):
        with self.assertRaisesRegex(ValueError, 'neighbouring'):
            audit(elf([(1, 6, 0, 0, 0, 8192, 8192, 16384), (0x6474e552, 4, 0, 0, 0, 4096, 4096, 1)]))
    def test_accept_ndk_relro_padding(self):
        audit(elf([(1, 6, 0, 0, 0, 4096, 4096, 16384), (1, 6, 16384, 16384, 0, 64, 64, 16384), (0x6474e552, 4, 0, 0, 0, 4096, 4096, 1)]))
    def test_reject_native_data_after_relro(self):
        with self.assertRaisesRegex(ValueError, 'neighbouring'):
            audit(elf([(1, 6, 0, 0, 0, 4096, 4096, 16384), (1, 6, 8192, 8192, 0, 64, 64, 16384), (0x6474e552, 4, 0, 0, 0, 4096, 4096, 1)]))
    def test_reject_malformed_header(self):
        with self.assertRaises(ValueError): audit(b'not an ELF')
    def test_accept_64k_load(self):
        self.assertEqual(audit(elf([(1, 5, 0, 0, 0, 100, 100, 65536)]))['minimumLoadAlignment'], 65536)

if __name__ == '__main__': unittest.main()
