package core

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"testing"
	"time"
)

func TestIPCachePersistenceAndExpiry(t *testing.T) {
	home := t.TempDir()
	now := time.Now()
	store := &ipCacheStore{}
	store.init(home)
	data := json.RawMessage(`{"score":28}`)
	if err := store.put("1.2.3.4", data, now); err != nil {
		t.Fatal(err)
	}
	reopened := &ipCacheStore{}
	reopened.init(home)
	if got := reopened.get("1.2.3.4", now.Add(ipCacheTTL-time.Second)); string(got) != string(data) {
		t.Fatalf("cache did not survive reopening: %s", got)
	}
	if got := reopened.get("1.2.3.4", now.Add(ipCacheTTL)); got != nil {
		t.Fatal("30-day entry must expire")
	}
	if err := reopened.put("1.2.3.4", json.RawMessage(`{"score":12}`), now.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if got := reopened.get("1.2.3.4", now.Add(ipCacheTTL)); string(got) != `{"score":12}` {
		t.Fatalf("refresh must replace data and reset expiry: %s", got)
	}
}

func TestIPCacheCapacityAndCorruption(t *testing.T) {
	store := &ipCacheStore{}
	store.init(t.TempDir())
	now := time.Now()
	entries := map[string]ipCacheEntry{}
	for i := 0; i < ipCacheLimit; i++ {
		entries[fmt.Sprint(i)] = ipCacheEntry{Saved: now.Add(time.Duration(i) * time.Second), Data: json.RawMessage(`{}`)}
	}
	encoded, err := encodeTrafficStore(entries)
	if err != nil {
		t.Fatal(err)
	}
	if err := writeTrafficStoreBytes(store.path, encoded); err != nil {
		t.Fatal(err)
	}
	later := now.Add(2 * time.Hour)
	if err := store.put("new", json.RawMessage(`{}`), later); err != nil {
		t.Fatal(err)
	}
	loaded := store.load(later)
	if len(loaded) != ipCacheLimit || loaded["0"].Data != nil || loaded["new"].Data == nil {
		t.Fatal("capacity must evict oldest entry")
	}
	if err := os.WriteFile(store.path, []byte("broken file"), 0600); err != nil {
		t.Fatal(err)
	}
	if got := store.get("new", later); got != nil {
		t.Fatal("corrupt file must be a cache miss")
	}
	if err := store.put("recovered", json.RawMessage(`{}`), later); err != nil {
		t.Fatal(err)
	}
	if store.get("recovered", later) == nil {
		t.Fatal("cache must recover after corruption")
	}
}

func TestIPCacheConcurrentWrites(t *testing.T) {
	store := &ipCacheStore{}
	store.init(t.TempDir())
	var workers sync.WaitGroup
	now := time.Now()
	for i := range 12 {
		workers.Add(1)
		go func() {
			defer workers.Done()
			if err := store.put(fmt.Sprint(i), json.RawMessage(`{}`), now); err != nil {
				t.Error(err)
			}
		}()
	}
	workers.Wait()
	if len(store.load(now)) != 12 {
		t.Fatal("concurrent writes lost data")
	}
}

func TestIPCacheKeys(t *testing.T) {
	for _, ip := range []string{"", "bad", "127.0.0.1", "192.168.1.1", "::1"} {
		if ipCacheKey(ip) != "" {
			t.Fatalf("accepted invalid/private key: %s", ip)
		}
	}
	if ipCacheKey("::ffff:1.2.3.4") != "1.2.3.4" {
		t.Fatal("IPv4-mapped keys must be normalized")
	}
}

func TestIPCacheSourcesStaySeparate(t *testing.T) {
	store := &ipCacheStore{}
	store.init(t.TempDir())
	now := time.Now()
	riskKey := ipCacheRecordKey(ipCacheParams{IP: "1.2.3.4"})
	locateKey := ipCacheRecordKey(ipCacheParams{IP: "1.2.3.4", Source: "iplocate"})
	if riskKey != "1.2.3.4" || riskKey == locateKey {
		t.Fatal("legacy risk keys must remain compatible and distinct from IPLocate")
	}
	if ipCacheRecordKey(ipCacheParams{IP: "1.2.3.4", Source: "unknown"}) != "" {
		t.Fatal("accepted unknown cache source")
	}
	if err := store.put(riskKey, json.RawMessage(`{"score":28}`), now); err != nil {
		t.Fatal(err)
	}
	if err := store.put(locateKey, json.RawMessage(`{"company":"Example"}`), now.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if string(store.get(riskKey, now.Add(time.Hour))) != `{"score":28}` {
		t.Fatal("IPLocate overwrote risk data")
	}
	if store.get(riskKey, now.Add(ipCacheTTL)) != nil {
		t.Fatal("IPLocate renewed risk expiry")
	}
	if store.get(locateKey, now.Add(ipCacheTTL)) == nil {
		t.Fatal("source expiry must be independent")
	}
}
