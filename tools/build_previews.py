"""Static, small ViewportFrame subsets of the actual native map geometry."""
from pathlib import Path
import xml.etree.ElementTree as E
import copy

ROOT=Path(__file__).resolve().parents[1]
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
        for item in source.iter('Item'):
            if item.get('class') not in ('Part','WedgePart'): continue
            label=item.findtext("Properties/string[@name='Name']") or ''
            if any(k in label.lower() for k in ('bounds','spawn','perímetro','contención')): continue
            p=item.find('Properties'); size=p.find("Vector3[@name='size']")
            if size is None: continue
            cf=p.find("CoordinateFrame[@name='CFrame']")
            if cf is not None and (abs(float(cf.findtext('X')))>70 or abs(float(cf.findtext('Z')))>60): continue
            xyz=[float(size.findtext(a)) for a in 'XYZ']; volume=xyz[0]*xyz[1]*xyz[2]
            if volume>8 and float(p.findtext("float[@name='Transparency']") or 0)<.5 and p.findtext("bool[@name='CanCollide']")=='true': candidates.append((volume,item))
        for index,(_,item) in enumerate(sorted(candidates,key=lambda c:c[0],reverse=True)[:42]):
            node=copy.deepcopy(item); node.set('referent',f'preview_{name}_{index}')
            for child in node.findall('Item'): node.remove(child)
            for prop in node.find('Properties'):
                if prop.get('name') in ('CanCollide','CanQuery','CanTouch'): prop.text='false'
            model.append(node)
    E.indent(root)
    (ROOT/'map/MapPreviews.rbxmx').write_bytes(E.tostring(root,encoding='utf-8',xml_declaration=True)+b'\n')
if __name__=='__main__': build()
