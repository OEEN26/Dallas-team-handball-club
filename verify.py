from pathlib import Path
from html.parser import HTMLParser
import re,subprocess
class Page(HTMLParser):
 def __init__(self):super().__init__();self.ids=[]
 def handle_starttag(self,tag,attrs):
  for k,v in attrs:
   if k=='id':self.ids.append(v)
for p in Path('.').glob('*.js'):
 r=subprocess.run(['node','--check',str(p)],capture_output=True,text=True);assert not r.returncode,(p,r.stderr)
for html in ['admin-awards.html','notifications.html','club-hub.html','player-dashboard.html']:
 p=Path(html);page=Page();page.feed(p.read_text());assert len(page.ids)==len(set(page.ids)),(html,'Duplicate ids')
 for s in re.findall(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>',p.read_text(),re.S|re.I):
  r=subprocess.run(['node','--check','-'],input=s,text=True,capture_output=True);assert not r.returncode,(html,r.stderr)
for html,js in [('admin-awards.html','admin-awards.js'),('notifications.html','notifications.js')]:
 page=Page();page.feed(Path(html).read_text());refs=set(re.findall(r"\$\('([\w-]+)'\)",Path(js).read_text()));assert not(refs-set(page.ids)),(html,refs-set(page.ids))
print('All script syntax, HTML ids and page control references passed.')
