import json,sys
for line in sys.stdin:
 o=json.loads(line)
 if 'id' in o: print(json.dumps({'jsonrpc':'2.0','id':o['id'],'result':{'tools':[]}}),flush=True)
