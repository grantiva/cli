import os,signal,sys
signal.pthread_sigmask(signal.SIG_BLOCK,{signal.SIGINT,signal.SIGTERM})
g,u=sys.argv[1:3]
os.execv(g,[g,'runner','start','--bundle-id','com.kylebrowning.Landmarks','--simulator',u,'--detach','--json'])
