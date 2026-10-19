# Build and reproduce

Use an isolated Windows VM and an internal HTTP service. Apply [the Sysmon configuration](../lab/sysmon-projects.xml), enable Security process creation with command lines, and enable PowerShell Script Block Logging before the run.

## Internal service

Create a service directory containing `beacon/status` and `health/check`, each with a short status response. Serve it on port 8766:

```bash
python3 -m http.server 8766 --directory http-root
```

Start a capture on the Windows-facing virtual interface before launching the profiles. The recorded run used QEMU user networking with a virtual-NIC packet capture; the Windows endpoint reached the host service as `10.0.2.2`. Use your own internal service address if your topology differs.

## Windows profiles

Copy the two scripts from `lab` to `C:\Users\Public\Documents\MohamedLab\Network`. Launch the following in separate PowerShell processes so they overlap:

```powershell
powershell.exe -NoProfile -File .\status-check.ps1 -Mode Fixed
powershell.exe -NoProfile -File .\status-check.ps1 -Mode Jitter
powershell.exe -NoProfile -File .\health-check.ps1
```

The default is 12 requests per profile. Both scripts accept `-Server` and `-Requests`. Outputs are written to `C:\ProgramData\MohamedLab\Network`. Use a fresh output directory for each run because the scripts append observations.

## Analysis and Splunk

Inspect [network.pcap](../evidence/network.pcap) in Wireshark using `http.request && tcp.port == 8766`. Compare `tcp.srcport` with `data.SourcePort` in the native Sysmon network events.

Install `splunk/app` as a local Splunk app. It defines index `lab_beacon` and the two sourcetypes. Import `evidence/events.jsonl` as `soc:windows:event` and `evidence/http-requests.jsonl` as `soc:network:http`. The latter is derived from the real capture and response observations, not a native proxy feed.

Open the Splunk dashboard views and run the SPL files. Compare the exported interval calculation with `interval-summary.csv`; sample standard deviation is used. Source UTC and indexed `_time` should represent the same instant.

## Cleanup

Stop the traffic processes and HTTP service. Remove only the case directories under `C:\Users\Public\Documents\MohamedLab\Network` and `C:\ProgramData\MohamedLab\Network` when the evidence is no longer needed.

## Capture helper

`lab/export-events.ps1` exports original event XML and matching normalized JSONL for a UTC window. For example: `./lab/export-events.ps1 -StartUtc $start -EndUtc $end -Output C:\MohamedLab\Evidence`. Record the UTC boundaries around your cases, then scope the capture to their PIDs, descendants and source record IDs before importing. The published selection is documented in `evidence/selection.json`; a full rerun capture may include additional background records.
