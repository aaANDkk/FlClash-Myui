package core

import "testing"

func TestCountryOfRecord(t *testing.T) {
	for _, test := range []struct {
		record any
		want   string
	}{
		{"us", "US"},
		{[]any{"LAN", "jp"}, "JP"},
		{map[string]any{"country": map[string]any{"iso_code": "DE"}}, "DE"},
		{nil, ""},
		{"ZZ", ""},
		{"XX", ""},
		{"private", ""},
	} {
		if got := countryOfRecord(test.record); got != test.want {
			t.Errorf("countryOfRecord(%v) = %q, want %q", test.record, got, test.want)
		}
	}
}

func TestIPCountryRejectsInvalidOrPrivateAddress(t *testing.T) {
	for _, ip := range []string{"invalid", "127.0.0.1", "10.0.0.1", "192.168.1.1", "::1", "fd00::1"} {
		if country := handleIPCountry(ipCountryParams{IP: ip}); country != "" {
			t.Errorf("country for %s = %q", ip, country)
		}
	}
}
