package core

import (
	"net/http"
	"testing"
	"time"
)

func TestCancelAllDelayTestsAbortsInFlightAndQueuedTests(t *testing.T) {
	withProbeProxies(t, "node-a")
	reached := make(chan struct{}, 1)
	hanging := probeServer(t, func(_ http.ResponseWriter, r *http.Request) {
		select {
		case reached <- struct{}{}:
		default:
		}
		select {
		case <-r.Context().Done():
		case <-time.After(5 * time.Second):
		}
	})

	inFlightDone := make(chan *Delay, 1)
	go func() {
		inFlightDone <- handleTestDelay(&TestDelayParams{
			ProxyName: "node-a",
			TestUrl:   hanging.URL,
			Timeout:   5000,
		})
	}()
	<-reached

	// Hold the remaining slots so a second request queues in acquireWithin.
	held := delayTestConcurrency - 1
	for range held {
		delayTestSlots <- struct{}{}
	}
	released := false
	releaseHeld := func() {
		if released {
			return
		}
		released = true
		for range held {
			<-delayTestSlots
		}
	}
	t.Cleanup(releaseHeld)

	queuedDone := make(chan *Delay, 1)
	go func() {
		queuedDone <- handleTestDelay(&TestDelayParams{
			ProxyName: "node-a",
			TestUrl:   hanging.URL,
			Timeout:   5000,
		})
	}()
	time.Sleep(30 * time.Millisecond)

	cancelAllDelayTests()
	releaseHeld()

	select {
	case got := <-queuedDone:
		if got != nil {
			t.Errorf("queued handleTestDelay = %+v, want nil when cancelled", got)
		}
	case <-time.After(time.Second):
		t.Fatal("queued handleTestDelay did not abort after cancelAllDelayTests")
	}

	select {
	case got := <-inFlightDone:
		if got != nil {
			t.Errorf("in-flight handleTestDelay = %+v, want nil when cancelled", got)
		}
	case <-time.After(time.Second):
		t.Fatal("in-flight handleTestDelay did not abort after cancelAllDelayTests")
	}

	if used := len(delayTestSlots); used != 0 {
		t.Errorf("delayTestSlots in use = %d, want 0 after cancellation", used)
	}
}
