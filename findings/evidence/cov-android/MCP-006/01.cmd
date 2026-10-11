$GRANTIVA hierarchy --format json > $S/gl.json; python3 -c "
import json
def walk(n):
    yield n
    for c in n.get(\"children\",[]): yield from walk(c)
for n in walk(json.load(open(\"$S/gl.json\"))):
    if n.get(\"identifier\")==\"gesture-pad\" or str(n.get(\"label\",\"\")).startswith((\"Taps\",\"Last\")) or str(n.get(\"text\",\"\")).startswith((\"Taps\",\"Last\")): print(json.dumps({k:n.get(k) for k in (\"identifier\",\"label\",\"text\",\"frame\")}))
"
