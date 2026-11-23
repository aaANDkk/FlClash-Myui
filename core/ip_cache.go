package core

import (
	"encoding/json"
	"net/netip"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const ipCacheTTL = 30 * 24 * time.Hour
const ipCacheLimit = 1024

type ipCacheEntry struct {
	Saved time.Time
	Data  json.RawMessage
}

// Entries are cached in memory and re-synced only when the backing file's
// metadata changes, avoiding repeated full-file decompression on concurrent
// lookups.
type ipCacheStore struct {
	mu      sync.Mutex
	path    string
	loaded  bool
	modTime time.Time
	size    int64
	entries map[string]ipCacheEntry
}

var ipCache ipCacheStore

type ipCacheParams struct {
	IP     string          `json:"ip"`
	Source string          `json:"source,omitempty"`
	Data   json.RawMessage `json:"data,omitempty"`
}

func (s *ipCacheStore) init(home string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.path = ""
	s.loaded = false
	s.modTime = time.Time{}
	s.size = 0
	s.entries = nil
	if home != "" {
		s.path = filepath.Join(home, "ip_cache.dat")
	}
}

func ipCacheEntryValid(entry ipCacheEntry, now time.Time) bool {
	return now.Before(entry.Saved.Add(ipCacheTTL)) && !entry.Saved.After(now) && json.Valid(entry.Data)
}

func (s *ipCacheStore) load(now time.Time) map[string]ipCacheEntry {
	entries := map[string]ipCacheEntry{}
	if !readTrafficStoreFile(s.path, &entries) || entries == nil {
		return map[string]ipCacheEntry{}
	}
	for key, entry := range entries {
		if !ipCacheEntryValid(entry, now) {
			delete(entries, key)
		}
	}
	return entries
}

func (s *ipCacheStore) syncFromDiskLocked(now time.Time) {
	info, err := os.Stat(s.path)
	if err != nil {
		s.loaded = false
		s.modTime = time.Time{}
		s.size = 0
		s.entries = nil
		return
	}
	if s.loaded && info.ModTime().Equal(s.modTime) && info.Size() == s.size {
		return
	}
	s.entries = s.load(now)
	s.loaded = true
	s.modTime = info.ModTime()
	s.size = info.Size()
}

func (s *ipCacheStore) get(ip string, now time.Time) json.RawMessage {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.path == "" {
		return nil
	}
	s.syncFromDiskLocked(now)
	if s.entries == nil {
		return nil
	}
	entry, ok := s.entries[ip]
	if !ok || !ipCacheEntryValid(entry, now) {
		return nil
	}
	return entry.Data
}

func (s *ipCacheStore) put(ip string, data json.RawMessage, now time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.path == "" {
		return nil
	}
	s.syncFromDiskLocked(now)
	entries := s.entries
	if entries == nil {
		entries = map[string]ipCacheEntry{}
	}
	for key, entry := range entries {
		if !ipCacheEntryValid(entry, now) {
			delete(entries, key)
		}
	}
	entries[ip] = ipCacheEntry{Saved: now, Data: data}
	for len(entries) > ipCacheLimit {
		oldest := ""
		for key, entry := range entries {
			if oldest == "" || entry.Saved.Before(entries[oldest].Saved) ||
				(entry.Saved.Equal(entries[oldest].Saved) && key < oldest) {
				oldest = key
			}
		}
		delete(entries, oldest)
	}
	encoded, err := encodeTrafficStore(entries)
	if err != nil {
		return err
	}
	if err := writeTrafficStoreBytes(s.path, encoded); err != nil {
		return err
	}
	s.entries = entries
	if info, err := os.Stat(s.path); err == nil {
		s.loaded = true
		s.modTime = info.ModTime()
		s.size = info.Size()
	} else {
		s.loaded = false
	}
	return nil
}

func ipCacheKey(ip string) string {
	addr, err := netip.ParseAddr(ip)
	if err != nil || !addr.IsGlobalUnicast() || addr.IsPrivate() {
		return ""
	}
	return addr.Unmap().String()
}

// Both sources share the same 30-day store and total entry limit, but cannot
// overwrite each other's payload or refresh timestamp.
func ipCacheRecordKey(params ipCacheParams) string {
	key := ipCacheKey(params.IP)
	if key == "" {
		return ""
	}
	switch params.Source {
	case "":
		return key // Preserve existing Scamalytics entries.
	case "iplocate":
		return "iplocate:" + key
	default:
		return ""
	}
}

func handleIPCacheGet(params ipCacheParams) json.RawMessage {
	if key := ipCacheRecordKey(params); key != "" {
		return ipCache.get(key, time.Now())
	}
	return nil
}

func handleIPCacheSet(params ipCacheParams) error {
	key := ipCacheRecordKey(params)
	// Persist only a small parsed result, never the remote HTML document.
	if key == "" || len(params.Data) > 64*1024 || !json.Valid(params.Data) || len(params.Data) == 0 || params.Data[0] != '{' {
		return &MethodError{Code: "invalid_arguments", Message: "invalid IP cache entry"}
	}
	return ipCache.put(key, params.Data, time.Now())
}
