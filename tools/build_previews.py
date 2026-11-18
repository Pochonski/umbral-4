"""Native landmark views, including finishes; no scripts or uploaded image assets.

Rank projected surface area, rather than only the biggest collision blocks.
The budget is per template; only two templates render during voting.
"""
from pathlib import Path
import xml.etree.ElementTree as E
import copy
import math

ROOT=Path(__file__).resolve().parents[1]
LIMIT=240
CAMERAS={
    'EstacionDeRelevo':((2,6.5,11),(0,2.4,0)),
    'PuertoDeCarga':((37,17,34),(-4,6,-7)),
    'InvernaderoDeProtocolo':((31,15,-34),(0,6,0)),
}
def build():
    root=E.Element('roblox',version='4')
    folder=E.SubElement(root,'Item',{'class':'Folder','referent':'previews'})
    props=E.SubElement(folder,'Properties'); E.SubElement(props,'string',name='Name').text='UmbralMapPreviews'
    for name in ['EstacionDeRelevo','PuertoDeCarga','InvernaderoDeProtocolo']:
        source=E.fromstring((ROOT/'map'/f'{name}.rbxmx').read_bytes())
        source=next(x for x in source.iter('Item') if x.get('class')=='Model' and x.findtext("Properties/string[@name='Name']")==name)
        model=E.SubElement(folder,'Item',{'class':'Model','referent':'preview_'+name})
        p=E.SubElement(model,'Properties'); E.SubElement(p,'string',name='Name').text=name
        candidates=[]
        landmark={part for group in source.iter('Item')
                  if (group.findtext("Properties/string[@name='Name']") or '').startswith('Celda 04')
                  for part in group.iter('Item')}
        eye,target=CAMERAS[name]
        forward=[b-a for a,b in zip(eye,target)]
        length=math.sqrt(sum(v*v for v in forward));forward=[v/length for v in forward]
        for item in source.iter('Item'):
            if item.get('class') not in ('Part','WedgePart'): continue
            label=item.findtext("Properties/string[@name='Name']") or ''
            if any(k in label.lower() for k in ('bounds','spawn')): continue
            p=item.find('Properties'); size=p.find("Vector3[@name='size']")
            if size is None: continue
            cf=p.find("CoordinateFrame[@name='CFrame']")
            if cf is None: continue
            pos=[float(cf.findtext(a)) for a in 'XYZ']
            if abs(pos[0])>85 or abs(pos[2])>85: continue
            delta=[a-b for a,b in zip(pos,eye)]
            if sum(a*b for a,b in zip(delta,forward)) < -8: continue
            xyz=sorted(float(size.findtext(a)) for a in 'XYZ')
            area=xyz[1]*xyz[2]
            if area<.18 or float(p.findtext("float[@name='Transparency']") or 0)>=.5: continue
            distance2=max(36,sum(v*v for v in delta))
            # Thin ribs, painted framing and neon strips contribute to identity.
            score=area/distance2
            if item in landmark: score*=12
            if any(k in label.lower() for k in ('núcleo','biorreactor','cultivo','transferencia','celda')): score*=1.5
            candidates.append((score,item))
        selected=sorted(candidates,key=lambda c:c[0],reverse=True)[:LIMIT]
        for index,(_,item) in enumerate(selected):
            node=copy.deepcopy(item); node.set('referent',f'preview_{name}_{index}')
            for child in node.findall('Item'): node.remove(child)
            for prop in node.find('Properties'):
                if prop.get('name') in ('CanCollide','CanQuery','CanTouch'): prop.text='false'
            model.append(node)
        count=E.SubElement(model,'Item',{'class':'IntValue','referent':'preview_count_'+name})
        props=E.SubElement(count,'Properties')
        E.SubElement(props,'string',name='Name').text='PreviewPartCount'
        E.SubElement(props,'int',name='Value').text=str(len(selected))
    E.indent(root)
    (ROOT/'map/MapPreviews.rbxmx').write_bytes(E.tostring(root,encoding='utf-8',xml_declaration=True)+b'\n')
if __name__=='__main__': build()
