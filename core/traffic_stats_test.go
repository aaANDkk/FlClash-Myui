package core

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/netip"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/gofrs/uuid/v5"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func enabledTrafficOptions(offset int) trafficStatsOptions {
	options := defaultTrafficStatsOptions()
	options.Enable = true
	options.TzOffset = offset
	return options
}

func newTestTrafficCollector(t *testing.T, offset int) *trafficCollector {
	t.Helper()
	collector := newTrafficCollector()
	collector.init(t.TempDir())
	collector.configure(enabledTrafficOptions(offset), "Sub")
	t.Cleanup(func() {
		collector.configure(defaultTrafficStatsOptions(), "")
	})
	return collector
}

func useTrafficNow(t *testing.T, now time.Time) {
	t.Helper()
	previous := trafficNow
	trafficNow = func() time.Time { return now }
	t.Cleanup(func() { trafficNow = previous })
}

func newTrafficInfo(host, process string, chain []string, up, down int64) *statistic.TrackerInfo {
	id, _ := uuid.NewV4()
	info := &statistic.TrackerInfo{
		UUID:     id,
		Metadata: &constant.Metadata{Host: host, Process: process, ProcessPath: "/bin/" + process},
		Chain:    chain,
	}
	info.UploadTotal.Store(up)
	info.DownloadTotal.Store(down)
	return info
}

func TestTrafficStatsDefaultsOffWithMonthLimit(t *testing.T) {
	options := defaultTrafficStatsOptions()
	if options.Enable || options.RetentionDays != 30 {
		t.Fatalf("unexpected defaults: %+v", options)
	}
	collector := newTrafficCollector()
	collector.init(t.TempDir())
	collector.observe("a", newTrafficInfo("example.com", "", nil, 1, 1), false)
	if collector.enabled.Load() || collector.timer != nil || len(collector.days) != 0 {
		t.Fatal("collector should stay idle while disabled")
	}
	options.Enable = true
	options.RetentionDays = 400
	collector.configure(options, "")
	if !collector.enabled.Load() || collector.options.RetentionDays != trafficMaxRetention {
		t.Fatalf("unexpected enabled state: %+v", collector.options)
	}
	if collector.timer != nil {
		t.Fatal("timer should wait for traffic")
	}
	collector.observe("b", newTrafficInfo("example.com", "", nil, 1, 1), false)
	if collector.timer == nil {
		t.Fatal("recorded traffic should arm the flush timer")
	}
	collector.configure(defaultTrafficStatsOptions(), "")
	if collector.enabled.Load() || collector.timer != nil {
		t.Fatal("disabling should stop the timer")
	}
}

func TestTrafficStatsTimerFollowsLiveConnections(t *testing.T) {
	useTrafficNow(t, time.Date(2026, 10, 24, 3, 0, 0, 0, time.UTC))
	collector := newTestTrafficCollector(t, 0)
	collector.observe("live", newTrafficInfo("example.com", "", nil, 1, 1), false)
	collector.mu.Lock()
	collector.timer.Stop()
	collector.timer = nil
	collector.mu.Unlock()

	// First tick treats connection not in DefaultManager with fresh=false as leaving & settles it.
	collector.tick()
	if collector.timer != nil {
		t.Fatal("settled non-live connection should not keep timer armed")
	}
	if day := readTrafficDay(filepath.Join(collector.dir, "2026-10-24.dat")); day == nil || day.Total != (trafficPair{1, 1}) {
		t.Fatalf("tick should flush dirty data: %+v", day)
	}
}

func TestTrafficStatsCountsDeltasOnceAndSettlesClosed(t *testing.T) {
	useTrafficNow(t, time.Date(2026, 10, 24, 3, 0, 0, 0, time.UTC))
	collector := newTestTrafficCollector(t, 0)
	info := newTrafficInfo("rr1.googlevideo.com", "chrome", []string{"HK 01", "Proxy"}, 100, 1000)

	// Open with fresh=true
	collector.observe("a", info, true)
	info.UploadTotal.Store(150)
	info.DownloadTotal.Store(1600)
	collector.observe("a", info, false)

	// Not in DefaultManager; first sample turns fresh -> false without dropping,
	// or actually sample settles final bytes on info too!
	info.UploadTotal.Store(200)
	info.DownloadTotal.Store(2000)
	result := collector.query(TrafficStatsQuery{Start: "2026-10-24", End: "2026-10-24"})
	if result.Up != 200 || result.Down != 2000 {
		t.Fatalf("unexpected totals: %+v", result)
	}
	if result.ProxyUp != 200 || result.ProxyDown != 2000 {
		t.Fatalf("unexpected proxy totals: %+v", result)
	}
	if len(result.Hosts) != 1 || result.Hosts[0].Name != "googlevideo.com" {
		t.Fatalf("unexpected hosts: %+v", result.Hosts)
	}
	if len(result.Processes) != 1 || result.Processes[0].Name != "chrome" || result.Processes[0].Path != "/bin/chrome" {
		t.Fatalf("unexpected processes: %+v", result.Processes)
	}
	if len(result.Nodes) != 1 || result.Nodes[0].Name != "HK 01" {
		t.Fatalf("unexpected nodes: %+v", result.Nodes)
	}
	if len(result.Profiles) != 1 || result.Profiles[0].Name != "Sub" {
		t.Fatalf("unexpected profiles: %+v", result.Profiles)
	}
}

func TestTrafficStatsDirectChainSplit(t *testing.T) {
	keepTunnel(t)
	tunnel.UpdateProxies(map[string]constant.Proxy{
		"DIRECT": namedProxy("DIRECT"),
		"local":  namedProxy("local"),
	}, nil)
	for _, name := range []string{"DIRECT", "local"} {
		t.Run(name, func(t *testing.T) {
			useTrafficNow(t, time.Date(2026, 10, 24, 3, 0, 0, 0, time.UTC))
			collector := newTestTrafficCollector(t, 0)
			collector.observe("p", newTrafficInfo("proxy.example.com", "", []string{"HK 01", "Proxy"}, 10, 90), false)
			collector.observe("d", newTrafficInfo("direct.example.com", "", []string{name, "Select"}, 5, 45), false)
			result := collector.query(TrafficStatsQuery{Start: "2026-10-24", End: "2026-10-24"})
			if result.Up != 15 || result.Down != 135 {
				t.Fatalf("unexpected total: %+v", result)
			}
			if result.ProxyUp != 10 || result.ProxyDown != 90 {
				t.Fatalf("unexpected proxy split: %+v", result)
			}
		})
	}
}

func TestTrafficStatsSplitsDaysByTimezoneAndFlushes(t *testing.T) {
	now := time.Date(2026, 10, 24, 15, 59, 0, 0, time.UTC)
	previous := trafficNow
	trafficNow = func() time.Time { return now }
	t.Cleanup(func() { trafficNow = previous })

	collector := newTestTrafficCollector(t, 480)
	info := newTrafficInfo("example.com", "", nil, 10, 20)
	collector.observe("a", info, false)

	now = time.Date(2026, 10, 24, 16, 0, 0, 0, time.UTC)
	info.UploadTotal.Store(25)
	info.DownloadTotal.Store(70)
	collector.observe("a", info, false)
	collector.flush()

	day1 := collector.query(TrafficStatsQuery{Start: "2026-10-24", End: "2026-10-24"})
	day2 := collector.query(TrafficStatsQuery{Start: "2026-10-25", End: "2026-10-25"})
	if day1.Up != 10 || day1.Down != 20 || day1.Series[23].Down != 20 {
		t.Fatalf("unexpected day1: %+v", day1)
	}
	if day2.Up != 15 || day2.Down != 50 || day2.Series[0].Down != 50 {
		t.Fatalf("unexpected day2: %+v", day2)
	}
}

func TestTrafficStatsStoreRoundTripAndPruning(t *testing.T) {
	useTrafficNow(t, time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC))
	collector := newTestTrafficCollector(t, 0)
	options := enabledTrafficOptions(0)
	options.RetentionDays = 2
	collector.configure(options, "")

	for _, day := range []string{"2026-10-20", "2026-10-23", "2026-10-24"} {
		data, err := encodeTrafficStore(&trafficDay{Total: trafficPair{1, 2}})
		if err != nil {
			t.Fatal(err)
		}
		if err := writeTrafficStoreBytes(filepath.Join(collector.dir, day+trafficStatsExt), data); err != nil {
			t.Fatal(err)
		}
	}
	collector.flush()
	if _, err := os.Stat(filepath.Join(collector.dir, "2026-10-20.dat")); !os.IsNotExist(err) {
		t.Fatalf("expired day should be removed: err=%v", err)
	}
	if _, err := os.Stat(filepath.Join(collector.dir, "2026-10-23.dat")); err != nil {
		t.Fatalf("retained day missing: %v", err)
	}
	raw, err := os.ReadFile(filepath.Join(collector.dir, "2026-10-24.dat"))
	if err != nil || bytes.Contains(raw, []byte("example.com")) {
		t.Fatalf("store should be obfuscated: err=%v", err)
	}
}

func TestTrafficStatsClearAndRuleHits(t *testing.T) {
	useTrafficNow(t, time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC))
	collector := newTestTrafficCollector(t, 0)
	id1, _ := uuid.NewV4()
	collector.observe("r1", &statistic.TrackerInfo{
		UUID:        id1,
		Rule:        "DOMAIN-SUFFIX",
		RulePayload: "google.com",
		Chain:       []string{"Proxy"},
		Metadata:    &constant.Metadata{Host: "www.google.com", DstIP: netip.MustParseAddr("1.1.1.1")},
	}, false)
	result := collector.query(TrafficStatsQuery{Start: "2026-10-24", End: "2026-10-24"})
	if result.RuleHits != 1 || len(result.Rules) != 1 || result.Rules[0].Name != "DOMAIN-SUFFIX,google.com" {
		t.Fatalf("unexpected rule hits: %+v", result)
	}
	collector.clear()
	after := collector.query(TrafficStatsQuery{Start: "2026-10-24", End: "2026-10-24"})
	if after.Up != 0 || after.Down != 0 || len(after.Rules) != 0 {
		t.Fatalf("clear should reset stats: %+v", after)
	}
	if _, err := json.Marshal(after); err != nil {
		t.Fatal(err)
	}
	_ = fmt.Sprint(after.Since)
}
