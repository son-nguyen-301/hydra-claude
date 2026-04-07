#!/bin/bash
# PostCompact hook: notify user on compaction done

# Read stdin (PostCompact JSON payload) — discard it, not needed
cat > /dev/null

# Print plain-text notification to stdout
echo "Context compacted. Token metrics updated."

exit 0
