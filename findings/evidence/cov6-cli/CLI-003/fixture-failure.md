# Preserved fixture failure

The first local regeneration used an absent `findings/help` directory, so the shell glob became one literal `*.txt` item and exited 1. It is excluded from grading. The corrected assessment joins the already accepted candidate5 docs-output smoke, which regenerated and validated all 172 help pages from this exact frozen candidate.
