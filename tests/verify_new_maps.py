"""Structural asset gate. Runtime navigation and combat require Studio as well."""
from pathlib import Path
import xml.etree.ElementTree as E
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
def verify():
    assert hashlib.sha256((ROOT/'map/EstacionDeRelevo.rbxmx').read_bytes().replace(b'\r\n',b'\n')).hexdigest() == '4e392786e6ee7cb75eb84c4390767f23028c62b167bb557eff06411780847aaa', 'Approved Relevo source changed'
    result={}
    for name in ['PuertoDeCarga','InvernaderoDeProtocolo']:
        xml=E.fromstring((ROOT/'map'/f'{name}.rbxmx').read_bytes()); items=list(xml.iter('Item'))
        assert all(i.get('class') in {'Model','Folder','Part','SurfaceGui','TextLabel','SurfaceLight'} for i in items)
        parts=[i for i in items if i.get('class')=='Part']; assert len(parts)<=800
        lights=[i for i in items if i.get('class')=='SurfaceLight']; assert len(lights)<=4
        bounds=next(i for i in parts if i.findtext("Properties/string[@name='Name']")=='PlayableBounds')
        bp=bounds.find('Properties'); center=[float(bp.findtext(f"CoordinateFrame/{a}")) for a in 'XYZ']; half=[float(bp.findtext(f"Vector3/{a}"))/2 for a in 'XYZ']
        markers=next(i for i in items if i.findtext("Properties/string[@name='Name']")=='Spawns').findall('Item')
        assert len(markers)==12
        for part in parts:
            p=part.find('Properties'); assert p.findtext("bool[@name='Anchored']")=='true'
            assert p.findtext("bool[@name='CanTouch']")=='false'
        for marker in markers:
            p=marker.find('Properties'); pos=[float(p.findtext(f"CoordinateFrame/{a}")) for a in 'XYZ']
            assert all(abs(v-c)<h for v,c,h in zip(pos,center,half))
            assert p.findtext("bool[@name='CanCollide']")=='false' and p.findtext("bool[@name='CanQuery']")=='false'
        for light in lights: assert light.findtext("Properties/bool[@name='Shadows']")=='false'
        result[name]={'parts':len(parts),'spawns':len(markers),'localLights':len(lights),'sha256':hashlib.sha256((ROOT/'map'/f'{name}.rbxmx').read_bytes()).hexdigest()}
    print(json.dumps({'structural':'PASS','relevoUnchanged':True,'maps':result},indent=2))
if __name__=='__main__': verify()
