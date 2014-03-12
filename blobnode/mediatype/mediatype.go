// Public Domain (-) 2014 The Wikifactory Authors.
// See the Wikifactory UNLICENSE file for details.

// Package mediatype tries to detect media types from byte streams.
package mediatype

import (
	"bytes"
	"fmt"
)

type startEntry struct {
	mediaType string
	signature []byte
}

var startDB = []startEntry{
	// Image types go first as a minor optimisation.
	{"image/gif", []byte("GIF87a")},
	{"image/gif", []byte("GIF89a")},
	{"image/jpeg", []byte("\xff\xd8\xff")},
	{"image/png", []byte("\x89PNG\r\n\x1a\n")},
	{"image/tiff", []byte("II*\x00")},
	{"image/tiff", []byte("MM\x00*")},
	{"application/pdf", []byte("%PDF")},
}

type multiEntry struct {
	mediaType  string
	signatures []sig
}

type sig struct {
	offset int
	bytes  []byte
}

var multiDB = []multiEntry{
	{"image/bmp", []sig{
		{0, []byte("BM")}, {6, []byte("\x00\x00\x00\x00")}}},
	{"image/webp", []sig{
		{0, []byte("RIFF")}, {8, []byte("WEBPVP8")}}},
}

func Detect(b []byte) string {
	l := len(b)
	for _, entry := range startDB {
		s := len(entry.signature)
		if l >= s && bytes.Equal(b[:s], entry.signature) {
			return entry.mediaType
		}
	}
multiLoop:
	for _, entry := range multiDB {
		for _, sig := range entry.signatures {
			s := len(sig.bytes) + sig.offset
			if !(l >= s && bytes.Equal(b[sig.offset:s], sig.bytes)) {
				continue multiLoop
			}
		}
		return entry.mediaType
	}
	return "application/octet-stream"
}
