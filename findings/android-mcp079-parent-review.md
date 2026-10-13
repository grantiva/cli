# Android MCP-079 parent review

PASS. The owned Android keepalive completes stock01-browse and stays alive while two separate MCP servers call grantiva_a11y_tree: another project with platform Android, and the owner project forced to iOS. Both raw JSON-RPC results contain result.isError:true and explicitly report No active runner session with one project/platform-mismatched keepalive ignored. Both client processes complete0; their wrapper success is not confused with tool success. Owner stop returns0 and the concurrently reaped successful flow returns0.

Evidence: cov3-android/findings/evidence/cov3-android/MCP-079-project-platform-tool-isolation-rerun1/. This complements the earlier context-only BC032 probes with actual session-tool refusals.
