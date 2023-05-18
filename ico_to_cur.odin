/*
	This code is horrible, I only know C,
	and this is the first time I am trying to
	write something in Odin, so it's bad, really bad.

	There are several issues, and I don't recommend
	anyone use this for any purpose whatsoever.

	That being said, please DO give feedback!
	Especially about code issues.
*/

package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"


// Lifted from: https://en.wikipedia.org/wiki/ICO_(file_format)
OFFSET_HEADER       :: 2
OFFSET_HEADER_VALUE :: 2
OFFSET_CURSOR_X     :: 0x0A
OFFSET_CURSOR_Y     :: 0x0C


main :: proc()
{
	buffer : [1024]u8
	x, y   : u16le

	fmt.println("Icon to cursor 0.0.1\n")
	for {
		fmt.printf("Enter filename (Example: \"file.ico\". Empty to quit).\n> ")
		n, e := os.read(os.stdin, buffer[:])

		if string_empty(buffer[:n]) {
			break
		}

		n = string_newlen(buffer[:n])

		x, y = get_dims()
		handle_file(buffer[:n], x, y)

		fmt.println("\n\n")
	}
}

string_empty :: proc(p : []u8) -> bool
{
	for i := 0; i < len(p); i += 1 {
		switch p[i] {
		case '\n', '\r', ' ', '\t': continue;
		case: return false
		}
	}

	return true
}

// This is terrible, just badness, horrible... But works for now :)
string_newlen :: proc(p : []u8) -> int
{
	if len(p) == 0 { return 0 }

	for i := len(p)-1; i >= 0; i -= 1 {
		switch p[i] {
		case '\n', '\r': continue
		case: return i+1
		}
	}

	return 0
}

get_dims :: proc() -> (u16le, u16le)
{
	buffer : [64]u8
	x, y   : u16le

	fmt.println("Enter X offset: ")
	os.read(os.stdin, buffer[:])
	x = u16le(strconv.atoi(string(buffer[:])))

	fmt.println("Enter Y offset: ")
	os.read(os.stdin, buffer[:])
	y = u16le(strconv.atoi(string(buffer[:])))

	return x, y
}

handle_file :: proc(p : []u8, x, y : u16le)
{
	buffer : [1024]u8
	bytes : int
	file_new, file_read : os.Handle
	err       : os.Errno

	if len(p) == 0 { return }

	// Open the file to convert.
	file_read, err = os.open(string(p[:]))
	if err != os.ERROR_NONE { return }
	defer { os.close(file_read) }

	// Create the new cursor file.
	file_new, err = os.open("NEWFILE.cur", os.O_CREATE | os.O_WRONLY)
	if err != os.ERROR_NONE { return }
	defer { os.close(file_new) }

	// For the first "page/buffer", we'll correct the
	// offsets and data, and then write to the new file.
	// After that, we'll just copy and paste into the new file.

	bytes, err = os.read(file_read, buffer[:])

	// TODO: Check if we read enough bytes.
	// if bytes < OFFSET_CURSOR_Y + 2 { return }

	// We'll use this to convert
	// an unsigned 16 little endian number
	// to a byte array.
	// I think there are other ways of doing this,
	// but I think this is the clearest/cleanest way of doing it.
	sequence :: struct #raw_union {
		num   : u16le,
		bytes : [2]u8
	}
	seq : sequence

	// '.ico' to '.cur' marker.
	seq.num = OFFSET_HEADER_VALUE
	buffer[OFFSET_HEADER  ] = seq.bytes[0]
	buffer[OFFSET_HEADER+1] = seq.bytes[1]

	seq.num = x
	buffer[OFFSET_CURSOR_X  ] = seq.bytes[0]
	buffer[OFFSET_CURSOR_X+1] = seq.bytes[1]

	seq.num = y
	buffer[OFFSET_CURSOR_Y  ] = seq.bytes[0]
	buffer[OFFSET_CURSOR_Y+1] = seq.bytes[1]

	os.write(file_new, buffer[:])

	// Now just copy and paste the rest of the file.
	for {
		bytes, err = os.read(file_read, buffer[:])
		if bytes == 0 || err != os.ERROR_NONE { break }

		os.write(file_new, buffer[:bytes])
	}
}
