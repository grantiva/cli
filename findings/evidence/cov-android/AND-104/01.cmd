MCP_WAIT=40 MCP_TIMEOUT=90 MCP_STDERR=$E/AND-104/server.err bash $S/tools/send.sh $P android $S/mcp/burst.jsonl > $S/burst.out; python3 -c "
import json
ids=[];err=0;iserr=0
for l in open(\"$S/burst.out\"):
    o=json.loads(l); 
    if \"error\" in o: err+=1
    if o.get(\"result\",{}).get(\"isError\"): iserr+=1
    ids.append(o.get(\"id\"))
print(\"responses\",len(ids),\"ids\",sorted(i for i in ids if i is not None),\"rpc_errors\",err,\"isError\",iserr)"
