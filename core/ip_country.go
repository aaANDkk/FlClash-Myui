package core

import (
	"net/netip"

	C "github.com/metacubex/mihomo/constant"
	"github.com/oschwald/maxminddb-golang"
)

type ipCountryParams struct {
	IP string `json:"ip"`
}

func handleIPCountry(params ipCountryParams) string {
	ip, err := netip.ParseAddr(params.IP)
	if err != nil || !ip.IsGlobalUnicast() || ip.IsPrivate() {
		return ""
	}
	reader, err := maxminddb.Open(C.Path.MMDB())
	if err != nil {
		return ""
	}
	defer reader.Close()
	var record any
	if err := reader.Lookup(ip.Unmap().AsSlice(), &record); err != nil {
		return ""
	}
	return countryOfRecord(record)
}

func countryOfRecord(record any) string {
	switch value := record.(type) {
	case string:
		code := normalizeRegion(value)
		if code != "ZZ" && code != "XX" {
			return code
		}
	case []any:
		for _, item := range value {
			if code := countryOfRecord(item); code != "" {
				return code
			}
		}
	case map[string]any:
		if country, ok := value["country"].(map[string]any); ok {
			return countryOfRecord(country["iso_code"])
		}
	}
	return ""
}
