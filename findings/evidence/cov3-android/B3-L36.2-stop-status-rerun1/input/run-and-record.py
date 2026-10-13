import pathlib,subprocess,sys
cwd,out,err,exitf,*argv=sys.argv[1:]
with open(out,'wb') as o, open(err,'wb') as e:
 r=subprocess.run(argv,cwd=cwd,stdout=o,stderr=e)
pathlib.Path(exitf).write_text(str(r.returncode)+'\n')
