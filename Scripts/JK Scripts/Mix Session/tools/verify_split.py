import re,sys,os,glob,collections
def load(p): return open(p,encoding="utf-8",errors="replace",newline="").read()
def parse(t):
    L=t.split("\n"); i=0; pre=[]
    while not L[i].startswith("  <TRACK"): pre.append(L[i]); i+=1
    tracks=[]
    while i<len(L) and L[i].startswith("  <TRACK"):
        j=i+1; ents=[]; 
        while not re.match(r"^  >\s*$",L[j]):
            if L[j].startswith("    <ITEM"):
                k=j+1
                while not re.match(r"^    >\s*$",L[k]): k+=1
                ents.append(("I","\n".join(L[j:k+1]))); j=k+1
            else: ents.append(("L",L[j])); j+=1
        guid=re.search(r"<TRACK (\{[^}]*\})",L[i]).group(1)
        nm=next((re.sub(r'^"|"$',"",m.group(1)) for e in ents if e[0]=="L" and (m:=re.match(r"^    NAME\s+(.*)$",e[1]))),"?")
        isb=next(((int(m.group(1)),int(m.group(2))) for e in ents if e[0]=="L" and (m:=re.match(r"^    ISBUS\s+(-?\d+)\s+(-?\d+)",e[1]))),(0,0))
        tracks.append(dict(guid=guid,head=L[i],name=nm,isbus=isb,ents=ents,end=L[j])); i=j+1
    return pre,tracks,L[i:]
def chains(tracks):
    st=[]; out=[]
    for t in tracks:
        out.append(tuple(st)); b=t["isbus"][1]
        if b>0: st+= [t["guid"]]*b
        elif b<0: del st[len(st)+b:]
    return out
def cue_of(item):
    f=re.search(r'FILE "([^"]*)"',item)
    if f:
        m=re.findall(r"(\d+M\d+) - ",f.group(1).split("/")[-1]); return m[-1] if m else None
    return None
def run(src,label):
    pre,tr,post=parse(load(src)); print("=====",label,"|",len(tr),"tracks")
    sch=chains(tr); sidx={t["guid"]:i for i,t in enumerate(tr)}
    allitems=collections.Counter(e[1] for t in tr for e in t["ents"] if e[0]=="I")
    srcmark=[l for l in pre if l.startswith("  MARKER")]
    bad=0
    for fn in sorted(glob.glob(src.rsplit(".",1)[0]+" - *.RPP")):
        code=re.search(r" - (\d+M\d+) - ",fn).group(1); errs=[]
        p2,t2,po2=parse(load(fn))
        if po2!=post: errs.append("post differs")
        # header: identical except CURSOR/SELECTION/MARKER
        h1=[l for l in pre if not re.match(r"  (MARKER|CURSOR|SELECTION)\b",l)]; h2=[l for l in p2 if not re.match(r"  (MARKER|CURSOR|SELECTION)\b",l)]
        if h1!=h2: errs.append("header differs beyond marker/cursor/selection")
        # order + settings
        pos=[sidx[t["guid"]] for t in t2]
        if pos!=sorted(pos): errs.append("track order changed")
        for t in t2:
            s=tr[sidx[t["guid"]]]
            sl=[e[1] for e in s["ents"] if e[0]=="L" and not e[1].startswith("    ISBUS")]
            ol=[e[1] for e in t["ents"] if e[0]=="L" and not e[1].startswith("    ISBUS")]
            if sl!=ol: errs.append("settings changed: "+t["name"])
            si=[e[1] for e in s["ents"] if e[0]=="I"]; oi=[e[1] for e in t["ents"] if e[0]=="I"]
            if any(x not in si for x in oi): errs.append("item not from source: "+t["name"])
            # item order within track preserved
            if [x for x in si if x in oi]!=oi: errs.append("item order changed: "+t["name"])
            for x in si:
                c=cue_of(x); isnote='FILE "' not in x
                if not isnote and c in (None,code) and x not in oi: errs.append("cue item missing: "+t["name"])
                if c not in (None,code) and x in oi: errs.append("foreign item kept: "+t["name"])
            if s["ents"] and any(e[0]=="I" for e in s["ents"]) and not oi: errs.append("emptied track kept: "+t["name"])
        # folder tree: output chains == source chains with removed ancestors dropped
        keptg={t["guid"] for t in t2}; och=chains(t2)
        for k,t in enumerate(t2):
            want=tuple(g for g in sch[sidx[t["guid"]]] if g in keptg)
            if och[k]!=want: errs.append("folder chain wrong: "+t["name"]); break
        d=0
        for t in t2:
            d+=t["isbus"][1]; a=t["isbus"][0]
            if (t["isbus"][1]>0)!=(a==1) or (t["isbus"][1]<0)!=(a==2): errs.append("ISBUS a/b mismatch: "+t["name"]); break
        if d!=0: errs.append("folders not closed")
        # a folder track with no kept children should not have b>0
        # markers
        ms=[l for l in p2 if l.startswith("  MARKER")]
        if any(m not in srcmark for m in ms): errs.append("marker not in source")
        # media
        files=re.findall(r'FILE "([^"]*)"',load(fn)); base=os.path.dirname(fn)
        miss=[f for f in files if not os.path.exists(f if f.startswith("/") else os.path.join(base,f))]
        # every item of THIS cue accounted for in source exactly
        ncue=sum(1 for t in t2 for e in t["ents"] if e[0]=="I" and cue_of(e[1])==code)
        scue=sum(c for x,c in allitems.items() if cue_of(x)==code)
        if ncue!=scue: errs.append(f"cue items {ncue} vs source {scue}")
        print(f"{code}: {'OK ' if not errs else 'FAIL'} items={sum(1 for t in t2 for e in t['ents'] if e[0]=='I')} tracks={len(t2)} media_refs={len(files)} missing_media={len(miss)}", ("; ".join(sorted(set(errs))[:4]) if errs else ""))
        bad+=len(errs)
    return bad
b1=run("/Users/jonathankawchuk/Documents/Projects/Film/Hunt for the Grey Ghost/HGG Mixing/HGG test pt delivery/HGG test pt delivery 2026-11-22-085634 name fix.RPP","delivery session")
b2=run("/Users/jonathankawchuk/Downloads/and back/HGG test pt delivery 2026-11-22-085634 name fix.rpp","pt round-trip session")
print("TOTAL PROBLEMS:",b1+b2)
