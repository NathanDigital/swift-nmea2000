# Upstream sync

Upstream: https://github.com/ttlappalainen/NMEA2000 (branch `master`)

| Date | Upstream commit | Notes |
|---|---|---|
| 2026-11-17 | `8d101b33e869` (2026-10-19) | Baseline commit that the port starts from |

To port newer upstream changes, review the diff since the last row (mainly `src/N2kMessages.*` and `src/N2kTypes.h`), port any new or fixed PGNs, and add a new row:

```sh
gh api repos/ttlappalainen/NMEA2000/compare/8d101b33e869...master --jq '.files[].filename'
```
