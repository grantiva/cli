import sys,os,json,datetime,glob
for d in sys.argv[1:]:
    f=json.load(open(d+'/flows/flow-000.json'))
    fail=[c for c in f['commands'] if c.get('status')=='failed'][0]
    et=datetime.datetime.fromisoformat(fail['endTime']).timestamp()
    arts=sorted(glob.glob(d+'/assets/flow-000/*'))+glob.glob(d+'/captures/failure-*.png')
    out=[]
    for a in arts:
        out.append('%s=+%.1fs'%(os.path.basename(a),os.stat(a).st_mtime-et))
    print(os.path.basename(d),'failed',fail['type'],'at',fail['endTime'],' '.join(out))
