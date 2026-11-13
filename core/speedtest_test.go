package core

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestSpeedTestStableSpeedSkipsRampUp(t *testing.T) {
	samples := []speedSample{
		{at: 0, bytes: 0},
		{at: 1 * time.Second, bytes: 10},
		{at: 2 * time.Second, bytes: 20},
		{at: 3 * time.Second, bytes: 1_000_020},
		{at: 4 * time.Second, bytes: 2_000_020},
		{at: 10 * time.Second, bytes: 8_000_020},
	}
	got := stableSpeed(samples)
	want := float64(8_000_020-20) * 8 / 8
	if got != want {
		t.Fatalf("stableSpeed = %v, want %v", got, want)
	}
	if stableSpeed(samples[:1]) != 0 {
		t.Fatal("stableSpeed with one sample should be 0")
	}
}

func TestSpeedTestWindowSpeed(t *testing.T) {
	samples := []speedSample{
		{at: 0, bytes: 0},
		{at: 500 * time.Millisecond, bytes: 100},
		{at: 1500 * time.Millisecond, bytes: 1100},
		{at: 2000 * time.Millisecond, bytes: 1600},
	}
	if got, want := windowSpeed(samples, time.Second), float64(1500*8)/1.5; got != want {
		t.Fatalf("windowSpeed = %v, want %v", got, want)
	}
}

func TestSpeedTestLatencyStats(t *testing.T) {
	latency, jitter := latencyStats([]float64{10, 14, 12, 20})
	if latency != 13 || jitter != (4.0+2+8)/3 {
		t.Fatalf("latencyStats = %v, %v", latency, jitter)
	}
}

func TestSpeedTestCancellationIsOwned(t *testing.T) {
	first, finishFirst := beginSpeedTest("first")
	defer finishFirst()
	second, finishSecond := beginSpeedTest("second")
	defer finishSecond()
	if first.Err() != context.Canceled {
		t.Fatal("previous run was not cancelled")
	}
	_ = handleCancelSpeedTest(SpeedTestCancelParams{ID: "first"})
	if second.Err() != nil {
		t.Fatal("old owner cancelled current run")
	}
	_ = handleCancelSpeedTest(SpeedTestCancelParams{ID: "second"})
	if second.Err() != context.Canceled {
		t.Fatal("current owner could not cancel")
	}
}

func TestSpeedTestCancelledPreparationFinishes(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	tester := newSpeedTester(SpeedTestParams{ID: "cancelled"}, true)
	entered := make(chan struct{})
	done := make(chan struct{})
	tester.prepare = func(ctx context.Context, _ *speedTester) (*speedTestTarget, error) {
		close(entered)
		<-ctx.Done()
		return nil, ctx.Err()
	}
	go func() {
		tester.run(ctx, func(SpeedTestState) {})
		close(done)
	}()
	<-entered
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("cancelled preparation did not release the run")
	}
	if got := tester.snapshot().Error; got != speedTestErrorCancelled {
		t.Fatalf("error = %q, want cancelled", got)
	}
}

func TestSpeedTestSpeedtestOnlyAndDirectRun(t *testing.T) {
	var downloads, uploads atomic.Int64
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/latency.txt":
			_, _ = io.WriteString(w, "test=test")
		case r.Method == http.MethodPost:
			n, _ := io.Copy(io.Discard, r.Body)
			uploads.Add(n)
			_, _ = io.WriteString(w, "ok")
		default:
			downloads.Add(4096)
			_, _ = io.WriteString(w, strings.Repeat("x", 4096))
			time.Sleep(time.Millisecond)
		}
	}))
	defer server.Close()
	oldScheme := speedtestNetScheme
	speedtestNetScheme = "http"
	defer func() { speedtestNetScheme = oldScheme }()
	tester := newSpeedTester(SpeedTestParams{ID: "owned", Provider: "apple", Duration: 1, Streams: 1,
		Server: &speedtestNetServer{Host: strings.TrimPrefix(server.URL, "http://"), Name: "Local", Sponsor: "Fixture"}}, true)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	tester.run(ctx, func(s SpeedTestState) {
		if s.ID != "owned" {
			t.Error("lost run identity")
		}
	})
	result := tester.snapshot()
	if result.Provider != "speedtest" || !result.Direct || result.Phase != speedTestPhaseDone || result.Error != "" {
		t.Fatalf("result = %+v", result)
	}
	if result.Download <= 0 || result.Upload <= 0 || downloads.Load() == 0 || uploads.Load() == 0 {
		t.Fatalf("missing throughput: %+v", result)
	}
	if result.Outbound == nil || len(result.Outbound.Chains) != 1 || result.Outbound.Chains[0] != "DIRECT" {
		t.Fatalf("bad outbound: %+v", result.Outbound)
	}
}
