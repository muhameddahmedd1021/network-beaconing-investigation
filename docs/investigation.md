# Investigation notes

## Environment

| Component | Configuration |
| --- | --- |
| Windows endpoint | `MOHAMEDAHMED`, Windows Server 2022 Evaluation |
| Local account | `MOHAMEDAHMED\mohamedahmed` |
| PowerShell | Windows PowerShell 5.1 |
| Endpoint telemetry | Sysmon process, network and file events; Security 4688; PowerShell 4104 |
| SIEM | Splunk Enterprise 9.4.1 on `MOHAMED-SIEM` |
| Service address | `10.0.2.2:8766`, reachable only inside the lab |

The Windows machine is standalone. The Linux VM hosts Splunk. All timestamps in the investigation are UTC.

## Collected evidence

The selected window is `2026-10-19T09:08:25.8513242Z` to `2026-10-19T09:12:20.9607829Z`. It contains **49 native Windows records**. The full selection is listed in [selection.json](../evidence/selection.json).

| Provider | Event ID | Records |
| --- | --- | ---: |
| Microsoft-Windows-Security-Auditing | 4688 | 3 |
| Microsoft-Windows-Sysmon | 1 | 3 |
| Microsoft-Windows-PowerShell | 4104 | 3 |
| Microsoft-Windows-Sysmon | 11 | 4 |
| Microsoft-Windows-Sysmon | 3 | 36 |

The normalized JSONL and original event XML identify the same channel/record-ID pairs. Event 4104 can be split into several parts; use its ScriptBlockId and part fields before interpreting long content. PID pivots are constrained to this host and time window, then checked against ProcessGuid.


## Correlation method

1. Limit the PCAP to the recorded UTC window and TCP port 8766. The published capture contains 365 packets from that scope.
2. Extract outbound HTTP GET requests. Remove retransmitted copies using the TCP source port and sequence number. Keep the original packet timestamp, URI and User-Agent.
3. Match each request's original source port to Sysmon Event 3 on `MOHAMEDAHMED`. Use the resulting PID and ProcessGuid to pivot to the process launch.
4. Check that the HTTP service observed the same request URI, and compare the response status with the output recorded by the Windows process. All 36 requests returned HTTP 200 in this run.
5. Sort each profile chronologically and subtract consecutive request timestamps. Compute the mean, sample standard deviation and coefficient of variation, `stdev / mean`, across 11 intervals per profile. Also compute the median interval, the median absolute deviation from it (MAD), and relative MAD, `MAD / median`.

The host-side HTTP service sees the virtual network's translated address. The packet capture and Sysmon contain the original endpoint connection. The correlation uses their ports rather than treating the service's translated source IP as the Windows IP.

## Timing results

| Profile | Requests | Mean interval, seconds | CV | Median, seconds | Relative MAD | PID |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Fixed | 12 | 6.085 | 0.484 | 4.774 | 0.054 | 3476 |
| Jitter | 12 | 7.361 | 0.369 | 7.552 | 0.321 | 2556 |
| Health | 12 | 5.316 | 0.364 | 4.533 | 0.038 | 2428 |

A CV-only filter below 0.20 did not select any of the three profiles in this sample. A few long intervals raise the standard deviation. The candidate search therefore compares the median absolute deviation with the median interval, `MAD / median`, and requires at least nine observed intervals and relative MAD below 0.20. `Fixed` and `Health` qualify; `Jitter` does not. The benign control still qualifies, so timing alone is insufficient. This is a lab triage threshold, not a universal detection rule. The exact candidate rows are in [the Splunk export](../evidence/search-results/03-periodic-candidates.csv).

`Fixed` and `Health` both use a four-second pause after each response. `Jitter` varies the pause. Measured start-to-start request intervals also include response time and VM scheduling, so they need not equal the configured sleep values.

## Analyst decision

Periodicity is a lead. Review the process command, parent, account, file origin, destination ownership, HTTP path and expected business activity. The authorized health check is a deliberate control for a false positive. The varying profile shows why inconsistent timing does not clear an endpoint by itself.

There is no real C2 server in this lab. The evidence supports repeated HTTP activity and the process responsible for it. It does not establish a real compromise, command exchange or data theft.
