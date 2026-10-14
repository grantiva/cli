# B-C05.1 verdict

Result: **pass**

With a failing grantiva stub first on PATH, grantiva_vrt_compare returned the real candidate error, the stub marker remained absent, and the server continued with 22 tools. This proves the server invoked its own absolute executable.
