# B3-L28 immutability observation

Result: **pass**

The exact installed `versions/` tree was hashed before and after one binary-alone `runner install` against the already-current isolated home. The install exited 0 with the required warning, and `cmp` of the complete sorted file/symlink manifests exited 0. No seed or fresh-home failure was repeated.
