package core

import (
	"bytes"
	crand "crypto/rand"
	"encoding/gob"
	"math/rand/v2"
	"os"
	"path/filepath"
)

const (
	trafficStoreVersion   byte = 1
	trafficStoreNonceSize      = 8
)

var (
	trafficStoreMagic = []byte("FCXS")
	trafficStoreSeed  = [32]byte{
		0x46, 0x6c, 0x43, 0x6c, 0x61, 0x73, 0x68, 0x2d, 0x73, 0x74, 0x6f, 0x72, 0x65, 0x2d, 0x76, 0x31,
		0x9e, 0x37, 0x79, 0xb9, 0x7f, 0x4a, 0x7c, 0x15, 0xf3, 0x9c, 0xc0, 0x60, 0x5c, 0xed, 0xc8, 0x34,
	}
)

func trafficStoreMask(nonce, data []byte) {
	seed := trafficStoreSeed
	for i, b := range nonce {
		seed[i] ^= b
	}
	stream := rand.NewChaCha8(seed)
	var block [4096]byte
	for offset := 0; offset < len(data); offset += len(block) {
		chunk := data[offset:min(offset+len(block), len(data))]
		_, _ = stream.Read(block[:len(chunk)])
		for i := range chunk {
			chunk[i] ^= block[i]
		}
	}
}

func encodeTrafficStore(value any) ([]byte, error) {
	var buf bytes.Buffer
	buf.Write(trafficStoreMagic)
	buf.WriteByte(trafficStoreVersion)
	nonce := make([]byte, trafficStoreNonceSize)
	_, _ = crand.Read(nonce)
	buf.Write(nonce)
	if err := gob.NewEncoder(&buf).Encode(value); err != nil {
		return nil, err
	}
	data := buf.Bytes()
	header := len(trafficStoreMagic) + 1
	trafficStoreMask(data[header:header+trafficStoreNonceSize], data[header+trafficStoreNonceSize:])
	return data, nil
}

func writeTrafficStoreBytes(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	temp := path + ".tmp"
	if err := os.WriteFile(temp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(temp, path)
}

func readTrafficStoreFile(path string, value any) bool {
	content, err := os.ReadFile(path)
	header := len(trafficStoreMagic) + 1
	if err != nil || len(content) < header+trafficStoreNonceSize || !bytes.HasPrefix(content, trafficStoreMagic) || content[header-1] != trafficStoreVersion {
		return false
	}
	body := content[header+trafficStoreNonceSize:]
	trafficStoreMask(content[header:header+trafficStoreNonceSize], body)
	return gob.NewDecoder(bytes.NewReader(body)).Decode(value) == nil
}
