"""Check thumbnail identity, source geometry, completeness metadata and render budget."""
from pathlib import Path
import importlib.util
import re
import xml.etree.ElementTree as E

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('previews',ROOT/'tools/build_previews.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)

def canonical(node):
    return (node.tag,tuple(sorted(node.attrib.items())),(node.text or '').strip(),tuple(canonical(c) for c in node))

def signature(item):
    return (item.get('class'),tuple(canonical(p) for p in item.find('Properties')
            if p.get('name') not in {'CanCollide','CanQuery','CanTouch'}))

folder=E.parse(ROOT/'map/MapPreviews.rbxmx').getroot().find('Item')
models=folder.findall('Item')
assert len(models)==3
cameras=re.findall(r'previewCamera\s*=\s*\{([^}]+)\}',(ROOT/'src/shared/Maps.luau').read_text(encoding='utf-8'))
assert len(cameras)==3
for index,model in enumerate(models):
    name=model.findtext("Properties/string[@name='Name']")
    assert name in builder.CAMERAS
    source=E.parse(ROOT/'map'/f'{name}.rbxmx')
    signatures={signature(i) for i in source.iter('Item') if i.get('class') in {'Part','WedgePart'}}
    parts=[i for i in model.findall('Item') if i.get('class') in {'Part','WedgePart'}]
    metadata=[i for i in model.findall('Item') if i.get('class')=='IntValue']
    assert 0<len(parts)<=builder.LIMIT and len(metadata)==1
    assert len(model.findall('Item'))==len(parts)+1
    assert metadata[0].findtext("Properties/string[@name='Name']")=='PreviewPartCount'
    assert int(metadata[0].findtext("Properties/int[@name='Value']"))==len(parts)
    for part in parts:
        assert signature(part) in signatures, f'{name}: invented or altered source geometry'
        assert not part.findall('Item'), f'{name}: child resources in thumbnail'
        assert part.findtext("Properties/bool[@name='Anchored']")=='true'
        for field in ['CanCollide','CanQuery','CanTouch']:
            assert part.findtext(f"Properties/bool[@name='{field}']")=='false'
    eye,target=builder.CAMERAS[name]
    assert tuple(float(v) for v in cameras[index].split(','))==(*eye,*target), f'{name}: curation camera drift'
    print(f'PASS {name}: {len(parts)} native parts, matching source, complete metadata, camera and query flags')
