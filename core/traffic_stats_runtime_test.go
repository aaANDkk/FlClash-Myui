package core

import (
	"testing"
	"time"
)

func trafficRuntimeClock(t *testing.T, initial time.Time) *time.Time {
	t.Helper()
	now := initial
	previous := trafficNow
	trafficNow = func() time.Time { return now }
	t.Cleanup(func() { trafficNow = previous })
	return &now
}

func TestTrafficStatsRunningTimeCountsIdleAndExcludesStoppedTime(t *testing.T) {
	now := trafficRuntimeClock(t, time.Date(2026, 11, 17, 0, 0, 0, 0, time.UTC))
	c := newTestTrafficCollector(t, 0)
	query := TrafficStatsQuery{Start: "2026-11-17", End: "2026-11-17"}
	*now = now.Add(time.Hour)
	if got := c.query(query).RunningSeconds; got != 0 {
		t.Fatalf("stopped service counted %d seconds", got)
	}
	c.setRunning(true)
	if c.timer == nil {
		t.Fatal("idle running service must checkpoint time without traffic")
	}
	*now = now.Add(90 * time.Second)
	for range 2 {
		if got := c.query(query).RunningSeconds; got != 90 {
			t.Fatalf("idle time counted incorrectly or twice: %d", got)
		}
	}
	*now = now.Add(30 * time.Second)
	c.setRunning(false)
	*now = now.Add(time.Hour)
	if got := c.query(query).RunningSeconds; got != 120 {
		t.Fatalf("stopped interval must not count: %d", got)
	}
	c.setRunning(true)
	*now = now.Add(time.Minute)
	if got := c.query(query).RunningSeconds; got != 180 {
		t.Fatalf("restarted service did not accumulate: %d", got)
	}
}

func TestTrafficStatsRunningTimeSplitsLocalMidnightAndPersists(t *testing.T) {
	now := trafficRuntimeClock(t, time.Date(2026, 11, 17, 15, 59, 30, 0, time.UTC))
	c := newTestTrafficCollector(t, 480)
	c.setRunning(true)
	*now = now.Add(90 * time.Second)
	c.setRunning(false)
	c.flush()
	loaded := newTrafficCollector()
	loaded.init(c.dir)
	for _, tc := range []struct {
		start, end string
		seconds    int64
	}{
		{"2026-11-17", "2026-11-17", 30},
		{"2026-11-18", "2026-11-18", 60},
		{"2026-11-17", "2026-11-18", 90},
	} {
		if got := loaded.query(TrafficStatsQuery{Start: tc.start, End: tc.end}).RunningSeconds; got != tc.seconds {
			t.Fatalf("persisted range %s..%s: got %d want %d", tc.start, tc.end, got, tc.seconds)
		}
	}
}

func TestTrafficStatsRunningTimeDisableSuspendAndClear(t *testing.T) {
	now := trafficRuntimeClock(t, time.Date(2026, 11, 17, 0, 0, 0, 0, time.UTC))
	c := newTestTrafficCollector(t, 0)
	query := TrafficStatsQuery{Start: "2026-11-17", End: "2026-11-17"}
	c.setRunning(true)
	*now = now.Add(time.Minute)
	c.configure(defaultTrafficStatsOptions(), "")
	*now = now.Add(time.Hour)
	c.configure(enabledTrafficOptions(0), "")
	*now = now.Add(time.Minute)
	c.setSuspended(true)
	*now = now.Add(time.Hour)
	c.setSuspended(false)
	*now = now.Add(time.Minute)
	if got := c.query(query).RunningSeconds; got != 180 {
		t.Fatalf("disabled/suspended time counted: %d", got)
	}
	c.clear()
	if got := c.query(query).RunningSeconds; got != 0 {
		t.Fatalf("cleared running time resurrected: %d", got)
	}
	*now = now.Add(1500 * time.Millisecond)
	for range 4 {
		c.query(query)
		*now = now.Add(250 * time.Millisecond)
	}
	if got := c.query(query).RunningSeconds; got != 2 {
		t.Fatalf("fractional checkpoint time was lost: %d", got)
	}
}

func TestTrafficStatsRunningTimeUsesCalendarClockWhileScreenIsOff(t *testing.T) {
	// A real time.Now carries the monotonic reading that was absent from the
	// original tests' time.Date fixtures. Do not retain it across device sleep.
	start := time.Now()
	now := trafficRuntimeClock(t, start)
	c := newTestTrafficCollector(t, 480)
	c.setRunning(true)
	if c.runningSince != start.Round(0) {
		t.Fatal("runtime checkpoint retains a suspend-sensitive monotonic clock")
	}
	c.setScreenOn(false)
	*now = start.Add(9*time.Hour + 49*time.Minute)
	c.flush()
	if c.runningSince != now.Round(0) {
		t.Fatal("flush restored a suspend-sensitive runtime checkpoint")
	}
	zone := time.FixedZone("test", 480*60)
	query := TrafficStatsQuery{
		Start: start.In(zone).Format(trafficDayLayout),
		End:   now.In(zone).Format(trafficDayLayout),
	}
	const expected = int64((9*time.Hour + 49*time.Minute) / time.Second)
	if got := c.query(query).RunningSeconds; got != expected {
		t.Fatalf("screen-off idle service: got %d seconds, want %d", got, expected)
	}
	c.setScreenOn(true)
	if got := c.query(query).RunningSeconds; got != expected {
		t.Fatalf("screen-on query counted the overnight span twice: %d", got)
	}
	loaded := newTrafficCollector()
	loaded.init(c.dir)
	if got := loaded.query(query).RunningSeconds; got != expected {
		t.Fatalf("overnight runtime did not survive disk reload: %d", got)
	}
}

func TestTrafficStatsRunningTimeOvernightIsSplitByCalendarDate(t *testing.T) {
	now := trafficRuntimeClock(t, time.Date(2026, 11, 17, 14, 14, 0, 0, time.UTC))
	c := newTestTrafficCollector(t, 480) // Local 22:14, then 08:03 the next day.
	c.setRunning(true)
	c.setScreenOn(false)
	*now = now.Add(9*time.Hour + 49*time.Minute)
	for _, tc := range []struct {
		start, end string
		want       int64
	}{
		{"2026-11-17", "2026-11-17", 106 * 60},
		{"2026-11-18", "2026-11-18", 483 * 60},
		{"2026-11-16", "2026-11-22", 589 * 60},
	} {
		if got := c.query(TrafficStatsQuery{Start: tc.start, End: tc.end}).RunningSeconds; got != tc.want {
			t.Fatalf("overnight %s..%s: got %d want %d", tc.start, tc.end, got, tc.want)
		}
	}
}

func TestTrafficStatsRunningTimeClockCorrectionDoesNotDoubleCount(t *testing.T) {
	now := trafficRuntimeClock(t, time.Date(2026, 11, 18, 1, 0, 0, 0, time.UTC))
	c := newTestTrafficCollector(t, 0)
	c.setRunning(true)
	query := TrafficStatsQuery{Start: "2026-11-18", End: "2026-11-18"}
	*now = now.Add(time.Hour)
	if got := c.query(query).RunningSeconds; got != 3600 {
		t.Fatalf("initial elapsed time: %d", got)
	}
	*now = now.Add(-30 * time.Minute)
	if got := c.query(query).RunningSeconds; got != 3600 {
		t.Fatalf("clock rollback changed accumulated time: %d", got)
	}
	*now = now.Add(31 * time.Minute)
	if got := c.query(query).RunningSeconds; got != 3660 {
		t.Fatalf("clock correction counted a span twice: %d", got)
	}
}
