# Candidate5 early iOS gate preexecution

Status: **bound, reviewed inputs pending root approval, not executed**.

`capture-one.rb` is an exact copy of the accepted candidate4 collector with four binding-only substitutions: candidate manifest path, manifest SHA-256, runner home, and session ID. Its unified diff, Ruby syntax result, and old/new hashes are adjacent.

`gate-bindings.json` fixes the candidate, frozen demo, source checkout, ownership, device UUIDs, collector, home, and session. `gate-commands.json` fixes the required order: iOS 26 stock, iOS 26 diff, iOS 27 stock, iOS 27 diff. The collector supplies both runner-home variables, removes the API key, rehashes the CLI/bundle/installed runner against the frozen manifest before every command, records exact argv/cwd/time/exit/raw streams, and observes Booted inventory before and after.

No runtime command has run from these files. Root must inspect the binding diff and activate the exclusive gate. Any iOS 26 failure stops before iOS 27. Cleanup remains separately scoped after gate disposition.
