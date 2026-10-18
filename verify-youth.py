from pathlib import Path
from html.parser import HTMLParser
import re,subprocess
class Page(HTMLParser):
 def __init__(self): super().__init__(); self.ids=[]; self.scripts=[]
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if 'id' in a:self.ids.append(a['id'])
  if tag=='script' and a.get('src','').startswith('./'):self.scripts.append(a['src'][2:].split('?')[0])
for p in Path('.').glob('*.js'):
 r=subprocess.run(['node','--check',str(p)],capture_output=True,text=True);assert r.returncode==0,(p,r.stderr)
for p in Path('.').glob('*.html'):
 page=Page();page.feed(p.read_text())
 assert len(page.ids)==len(set(page.ids)),(p,'duplicate HTML ids')
 for script in re.findall(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>',p.read_text(),re.S|re.I):
  r=subprocess.run(['node','--check','-'],input=script,text=True,capture_output=True);assert r.returncode==0,(p,r.stderr)
for html,js in [('youth-registration.html','youth-registration.js'),('admin-youth.html','admin-youth.js'),('signup.html','youth-signup.js'),('season-registration.html','season-registration.html'),('season-player-agreement.html','season-player-agreement.js')]:
 page=Page();page.feed(Path(html).read_text());ids=set(page.ids)
 static=set(re.findall(r"\$\('([a-zA-Z][\w-]*)'\)",Path(js).read_text()))
 if html=='signup.html':static-= {'guardianAttestation'}
 assert not (static-ids),(html,'missing elements',static-ids)
print('Script syntax, HTML ids and form control references passed.')
