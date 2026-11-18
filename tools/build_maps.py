"""Deterministic, editable native Roblox map assets. No external assets or scripts."""
from math import sin, cos, radians, sqrt, degrees, atan2
from pathlib import Path
import xml.etree.ElementTree as E

OUT = Path(__file__).resolve().parents[1] / 'map'
STEEL=(29,48,63); EDGE=(77,105,119); WHITE=(207,220,216); INK=(15,29,38)
AMBER=(247,184,66); CYAN=(93,205,205); GREEN=(94,137,100); FLOOR=(114,132,139)

class Map:
    def __init__(self, name, width, depth):
        self.name=name; self.xml=E.Element('roblox', version='4'); self.serial=0; self.count=0
        self.model=self.obj(self.xml,'Model',name); self.name=name
        self.structure=self.obj(self.model,'Folder','Arquitectura')
        self.detail=self.obj(self.model,'Folder','Acabados')
        self.background=self.obj(self.model,'Folder','Fondo inaccesible')
        self.spawns=self.obj(self.model,'Folder','Spawns')
        self.part(self.model,'PlayableBounds',(0,18,0),(width+2,76,depth+2),INK,solid=False,query=False,transparency=1)
        self.part(self.structure,'Losa continua',(0,-1,0),(width,2,depth),FLOOR,816)
        for axis, limit, other in [('X',width/2,depth),('Z',depth/2,width)]:
            for sign in [-1,1]:
                pos=(sign*limit,9,0) if axis=='X' else (0,9,sign*limit)
                size=(1.6,18,other+1.6) if axis=='X' else (other+1.6,18,1.6)
                self.part(self.structure,'Muro de contención',pos,size,STEEL,816)
                top=(pos[0],18.1,pos[2]); cap=(2,.3,other+2) if axis=='X' else (other+2,.3,2)
                self.part(self.detail,'Remate de perímetro',top,cap,EDGE,solid=False)
        for x in range(-int(width/2)+8,int(width/2),12):
            self.part(self.detail,'Junta de losa',(x,.012,0),(.055,.02,depth-2),EDGE,solid=False,query=False)
        for z in range(-int(depth/2)+8,int(depth/2),12):
            self.part(self.detail,'Junta de losa',(0,.013,z),(width-2,.02,.055),EDGE,solid=False,query=False)
        for x,z in [(-width/2+11,-depth/2+12),(0,-depth/2+5),(width/2-11,-depth/2+12),
                    (-width/2+4,-depth/2+30),(width/2-4,-depth/2+30),
                    (-width/2+4,0),(width/2-4,0),
                    (-width/2+4,depth/2-30),(width/2-4,depth/2-30),
                    (-width/2+11,depth/2-12),(0,depth/2-5),(width/2-11,depth/2-12)]:
            self.part(self.spawns,f'Spawn {len(self.spawns.findall("Item"))+1:02}',(x,3,z),(2,1,2),CYAN,
                      solid=False,query=False,transparency=1,yaw=degrees(atan2(x,z)))

    def obj(self,parent,kind,name):
        self.serial+=1
        item=E.SubElement(parent,'Item',{'class':kind,'referent':f'{self.name}_{self.serial}'})
        p=E.SubElement(item,'Properties'); E.SubElement(p,'string',name='Name').text=name
        return item

    def prop(self,item,kind,name,value):
        E.SubElement(item.find('Properties'),kind,name=name).text=str(value).lower() if isinstance(value,bool) else str(value)

    def vector(self,item,kind,name,axes,values):
        p=E.SubElement(item.find('Properties'),kind,name=name)
        for a,v in zip(axes,values): E.SubElement(p,a).text=str(round(v,6))

    def part(self,parent,name,pos,size,color,material=1088,solid=True,query=True,transparency=0,yaw=0,tilt=0,shape=1):
        item=self.obj(parent,'Part',name); self.count+=1
        cy,sy,ct,st=cos(radians(yaw)),sin(radians(yaw)),cos(radians(tilt)),sin(radians(tilt))
        self.vector(item,'CoordinateFrame','CFrame',['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'],
                    (*pos,cy,sy*st,sy*ct,0,ct,-st,-sy,cy*st,cy*ct))
        self.vector(item,'Vector3','size','XYZ',size)
        self.prop(item,'Color3uint8','Color3uint8',(color[0]<<16)|(color[1]<<8)|color[2])
        self.prop(item,'token','Material',material); self.prop(item,'token','shape',shape)
        for k,v in [('Anchored',True),('CanCollide',solid),('CanQuery',query),('CanTouch',False),('CastShadow',transparency<.5)]: self.prop(item,'bool',k,v)
        self.prop(item,'float','Transparency',transparency)
        for face in ['Top','Bottom','Front','Back','Left','Right']: self.prop(item,'token',face+'Surface',0)
        return item

    def sign(self,pos,size,title,color=WHITE,yaw=0):
        host=self.part(self.detail,'Señal · '+title,pos,size,INK,solid=False,yaw=yaw)
        gui=self.obj(host,'SurfaceGui','Rotulación')
        self.prop(gui,'token','Face',5); self.prop(gui,'float','PixelsPerStud',34)
        self.prop(gui,'float','LightInfluence',0); self.prop(gui,'float','Brightness',1); self.prop(gui,'token','SizingMode',1); self.prop(gui,'bool','AlwaysOnTop',False)
        t=self.obj(gui,'TextLabel','Texto'); self.prop(t,'string','Text',title)
        self.prop(t,'bool','TextScaled',True); self.prop(t,'float','BackgroundTransparency',1)
        self.prop(t,'token','Font',18)
        self.vector(t,'Color3','TextColor3','RGB',[v/255 for v in color])
        self.vector(t,'UDim2','Size',['XS','XO','YS','YO'],[1,0,1,0])

    def lamp(self,x,y,z,color):
        host=self.part(self.detail,'Luminaria de servicio',(x,y,z),(3,.24,1.2),color,288,solid=False)
        light=self.obj(host,'SurfaceLight','Luz de galería')
        self.prop(light,'token','Face',4); self.prop(light,'float','Brightness',.8)
        self.prop(light,'float','Range',15); self.prop(light,'float','Angle',100)
        self.prop(light,'bool','Shadows',False)
        self.vector(light,'Color3','Color','RGB',[v/255 for v in color])

    def stripe(self,x,z,length,color=AMBER):
        self.part(self.detail,'Marca superficial',(x,.026,z),(length,.025,.16),color,272,solid=False,query=False)

    def container(self,x,z,title,color):
        # All opaque relief is queryable. Ribs sit against an opaque backing.
        self.part(self.structure,title,(x,4,z),(22,8,12),color)
        self.part(self.detail,'Zócalo',(x,.5,z),(22.3,1,12.3),INK,solid=False)
        self.part(self.detail,'Cornisa',(x,8.12,z),(22.5,.24,12.5),EDGE,solid=False)
        for dz in [-6.06,6.06]:
            for dx in range(-9,10,3):
                self.part(self.detail,'Nervio del contenedor',(x+dx,4.1,z+dz),(.14,6.8,.15),EDGE,solid=False)
        self.sign((x,6.5,z-6.18),(15,1,.12),title,AMBER)
        self.part(self.detail,'Cierre de carga',(x,3.1,z-6.2),(.16,4.8,.2),WHITE,solid=False)
        for dx in [-3,3]: self.part(self.detail,'Cerrojo',(x+dx,3,z-6.24),(.12,4.1,.12),WHITE,solid=False)

    def catwalk(self,x,label,color=AMBER):
        self.part(self.structure,'Galería '+label,(x,7.6,0),(12,.8,26),EDGE)
        for z in [-22,22]:
            self.part(self.structure,'Rampa '+label,(x,3.85,z),(12,.7,sqrt(18**2+7.7**2)),EDGE,tilt=23.2 if z>0 else -23.2)
        for dx in [-5.7,5.7]:
            self.part(self.structure,'Barandilla continua',(x+dx,9.5,0),(.22,.25,26),WHITE)
            for z in [-12,-6,0,6,12]:
                self.part(self.structure,'Montante',(x+dx,8.8,z),(.24,2.1,.24),STEEL)
            self.part(self.detail,'Banda de borde',(x+dx,8.05,0),(.13,.08,26),color,solid=False)
        for z in [-10,10]:
            self.part(self.structure,'Apoyo de galería',(x,3.5,z),(1.2,7,1.2),STEEL)
            self.part(self.detail,'Viga transversal',(x,6.9,z),(12.6,.5,.8),STEEL,solid=False)
        # Middle strips are flush with a walkable backing.
        for z in range(-12,13,3): self.part(self.detail,'Junta de pasarela',(x,8.015,z),(11,.02,.09),INK,solid=False,query=False)
        self.sign((x,5.7,-13.55),(9,1.2,.15),label,color)

    def save(self):
        assert self.count <= 800, self.count
        E.indent(self.xml)
        (OUT/(self.name+'.rbxmx')).write_bytes(E.tostring(self.xml,encoding='utf-8',xml_declaration=True)+b'\n')
        print(f'{self.name}: {self.count} parts')

def cargo():
    m=Map('PuertoDeCarga',128,112)
    for x,z,title,color in [(-28,-16,'C1 / EXPORTACIÓN',(44,78,97)),(-28,16,'C2 / TRÁNSITO',(49,69,83)),
                            (26,-16,'C3 / CONTROL',(174,141,74)),(26,16,'C4 / RESERVA',(42,77,91)),
                            (0,-37,'C5 / DESPACHO',(58,83,95)),(0,37,'C6 / RECEPCIÓN',(167,127,64))]: m.container(x,z,title,color)
    m.catwalk(48,'MUELLE / CONTROL')
    # Landmark: transfer tower, grounded in a single central cover mass.
    m.part(m.structure,'Torre de transferencia',(0,6,0),(12,12,12),STEEL)
    for x in [-5.7,5.7]:
        for z in [-5.7,5.7]: m.part(m.detail,'Pilar de transferencia',(x,9,z),(1,18,1),WHITE,solid=False)
    m.part(m.detail,'Cabezal de transferencia',(0,17,0),(14,2,14),STEEL,solid=False)
    for z in [-6.1,6.1]:
        m.part(m.detail,'Franja del núcleo',(0,10,z),(10,.5,.16),AMBER,288,solid=False)
    m.sign((0,6,-6.13),(10,2,.16),'T0 / TRANSFERENCIA',AMBER)
    m.sign((0,6,6.13),(10,2,.16),'T0 / TRANSFERENCIA',AMBER,yaw=180)
    for x in [-6.08,6.08]:
        m.part(m.detail,'Panel de disipación',(x,5,0),(.16,8,8),EDGE,solid=False)
        for y in [2,3,4,5,6,7,8]: m.part(m.detail,'Lama de disipación',(x*1.015,y,0),(.12,.12,6.6),INK,solid=False)
    for x in [-4,4]:
        m.part(m.detail,'Canal de transferencia',(x,3,-6.18),(.3,4.6,.3),EDGE,solid=False)
    for z in [-26,26]:
        for dx in [-6,-3,0,3,6]:
            m.part(m.detail,'Área de maniobra',(dx,.03,z),(.7,.03,2.8),AMBER,272,solid=False,query=False,yaw=35)
    for x in [-46]:
        for z in [-25,0,25]:
            m.part(m.structure,'Barrera de muelle',(x,1.6,z),(3.5,3.2,5),WHITE,816)
            m.part(m.detail,'Banda de seguridad',(x,3.22,z),(3.6,.1,5.1),AMBER,solid=False)
    for z in [-47,-29,-3,29,47]:
        for x in [-42,0,41]: m.stripe(x,z,9)
    m.sign((0,13,-55),(36,2,.3),'PUERTO DE CARGA  /  TERMINAL 02',AMBER)
    m.sign((-62.9,9,15),(22,1.6,.2),'SERVICIO / RUTA OESTE',WHITE,yaw=90)
    for x,z in [(-48,-40),(48,40)]: m.lamp(x,13,z,AMBER)
    # Gantries and ship silhouette are outside the tall physical perimeter.
    for x in [-42,42]:
        m.part(m.background,'Pata de grúa',(x,22,-70),(4,44,4),STEEL,solid=False,query=False)
        m.part(m.background,'Carril elevado',(x,43,-33),(3,3,82),AMBER,solid=False,query=False)
    m.part(m.background,'Puente de grúa',(0,43,-70),(88,4,5),AMBER,solid=False,query=False)
    for x in [-36,-18,0,18,36]: m.part(m.background,'Refuerzo del puente',(x,47,-70),(1,6,3),STEEL,solid=False,query=False)
    m.part(m.background,'Casco logístico',(-4,4,-97),(116,15,28),STEEL,solid=False,query=False)
    for x in [-35,-8,19]:
        m.part(m.background,'Carga embarcada',(x,16,-97),(24,10,20),EDGE,solid=False,query=False)
        m.part(m.background,'Carga embarcada',(x,26,-97),(24,10,20),(109,125,127),solid=False,query=False)
    m.save()

def greenhouse():
    m=Map('InvernaderoDeProtocolo',112,104)
    # Lower wall liners create a brighter, coherent interior without openings that look passable.
    for x in [-54.9,54.9]:
        m.part(m.detail,'Revestimiento sanitario',(x,5,0),(.25,10,100),WHITE,solid=False)
        for z in range(-44,45,11): m.part(m.detail,'Junta vertical',(x-.2 if x>0 else x+.2,5,z),(.08,9,.06),EDGE,solid=False)
    m.part(m.structure,'Núcleo de cultivo',(0,3.5,0),(18,7,20),WHITE,1088)
    m.part(m.detail,'Bancada del núcleo',(0,.5,0),(18.4,1,20.4),STEEL,solid=False)
    for x in [-6,0,6]:
        m.part(m.structure,'Columna de biorreactor',(x,9.5,0),(4,12,4),EDGE)
        for y in [5,9,13]:
            m.part(m.detail,'Anillo de biosistema',(x,y,0),(4.2,.35,4.2),CYAN,288,solid=False)
    m.sign((0,5,-10.2),(15,1.6,.2),'N0 / CULTIVO CENTRAL',CYAN)
    for x in [-6,0,6]:
        m.part(m.detail,'Cartucho de cultivo',(x,10,-2.08),(2.8,5,.16),GREEN,272,solid=False)
        m.part(m.detail,'Panel de mantenimiento',(x,2.2,-10.13),(4.8,2.4,.22),(165,189,188),solid=False)
    for x in [-41,41]: m.catwalk(x,'GALERÍA '+('OESTE' if x<0 else 'ESTE'),CYAN)
    for x in [-25,25]:
        for z in [-25,25]:
            m.part(m.structure,'Módulo de mantenimiento',(x,3,z),(12,6,9),STEEL)
            m.part(m.detail,'Tapa de mantenimiento',(x,6.15,z),(12.4,.3,9.4),WHITE,solid=False)
            m.sign((x,4.6,z-4.65),(10,1.1,.2),'REFRIGERACIÓN' if x>0 else 'PROTOCOLO / 03',CYAN)
            for dx in [-4,-2,0,2,4]:
                m.part(m.detail,'Rejilla de servicio',(x+dx,2.5,z-4.58),(.16,2.4,.13),EDGE,solid=False)
    for z in [-39,39]:
        m.part(m.structure,'Banco técnico',(0,2,z),(21,4,6),WHITE,816)
        m.part(m.detail,'Superficie técnica',(0,4.1,z),(21.3,.2,6.3),STEEL,solid=False)
        m.stripe(0,z-4,22,CYAN)
    for x in [-8,8]:
        for z in [-10.12,10.12]:
            m.part(m.detail,'Montante del cultivo',(x,3.8,z),(.3,6.2,.25),EDGE,solid=False)
    for z in [-34,34]:
        for x in [-9,-6,-3,0,3,6,9]:
            m.part(m.detail,'Canal de drenaje',(x,.025,z),(1.6,.025,.22),INK,272,solid=False,query=False)
    for x in [-24,24]:
        m.part(m.detail,'Guía de circulación',(x,.027,0),(.15,.025,85),CYAN,272,solid=False,query=False)
    for x in [-41,41]:
        for z in [-8,8]: m.lamp(x,14,z,WHITE)
    m.sign((0,13,-50.9),(38,2,.25),'INVERNADERO DE PROTOCOLO',CYAN)
    # Inaccessible cultivation beds are behind the solid perimeter.
    for x in [-63,63]:
        for z in [-35,0,35]:
            m.part(m.background,'Jardinera exterior',(x,2,z),(9,4,22),WHITE,solid=False,query=False)
            for dz in [-7,0,7]:
                m.part(m.background,'Tronco de cultivo',(x,12,z+dz),(.5,24,.5),EDGE,solid=False,query=False)
                m.part(m.background,'Copa de cultivo',(x,22,z+dz),(9,10,9),GREEN,272,solid=False,query=False,shape=0)
    for z in [-55,-27,0,27,55]:
        for x in [-60,60]: m.part(m.background,'Columna del invernadero',(x,15,z),(1.3,30,1.3),WHITE,solid=False,query=False)
        m.part(m.background,'Viga de cubierta',(0,29,z),(122,1.2,1.2),WHITE,solid=False,query=False)
    for x in [-30,30]:
        m.part(m.background,'Cubierta translúcida',(x,29.7,0),(58,.3,112),(169,202,198),1568,solid=False,query=False,transparency=.72)
    m.save()

if __name__=='__main__': cargo(); greenhouse()
