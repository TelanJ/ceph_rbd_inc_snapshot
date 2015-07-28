## snapinc


Snapinc is a cli client for backup/restore/purge of ceph rbd images from local machines to remote machines and vice-versa.

Syntax: 

snapinc <options>

For backup (local to remote),  
  snapinc -b -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST]  
  or  
  snapic -m backup -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST]  
         
For restore (remote to local),  
  snapinc -r -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST] [-c [CHOSEN_DATE](optional)]  
  or  
  snapic -m restore -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST] [-c [CHOSEN_DATE] (optional)]  
         
For purge (delete remote),  
  snapinc -p -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST]  
  or  
  snapic -m purge -s [SOURCEPOOL] -d [DESTPOOL] -e [DESTHOST] [-c [CHOSEN_DATE] (optional)]  
         