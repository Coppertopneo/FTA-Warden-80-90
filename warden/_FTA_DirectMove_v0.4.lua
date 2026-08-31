local WGG = ...
if not WGG then error("[FTA-DIRECT] WGG environment not provided") end
local VERSION = "0.4-live-npc-interact"
local PREFIX = "|cff71d5ff[FTA-DIRECT]|r "
local CFG = {
tick = 0.10,
mountDistance = 55,
flyDistance = 120,
maxMountAttempts = 3,
mountRetry = 4.0,
maxTakeoffAttempts = 5,
takeoffRetry = 3.2,
cruiseHeight = 32,
approachDistance = 160,
nearGroundHeight = 3,
maxPitchUp = math.rad(32),
maxPitchDown = math.rad(-38),
takeoffPitch = math.rad(20),
recoveryPitch = math.rad(38),
raycastInterval = 0.35,
obstacleGround = 16,
obstacleFly = 24,
obstacleCooldown = 1.2,
progressWindow = 2.8,
minProgress = 1.2,
maxRecoveries = 7,
detourForward = 10,
detourSide = 13,
detourSeconds = 1.5,
climbSeconds = 1.8,
minArrivalRadius = 4,
landingDistance = 65,
finalLandingDistance = 24,
finalLandingAltitude = 10,
landedAltitude = 3,
surgeMinDistance = 300,
surgeStopDistance = 200,
surgeInterval = 7.0,
scanMarkerRadius = 18,
scanPlayerRadius = 16,
interactDistance = 5.8,
interactRetryDelay = 2.0,
maxInteractCandidates = 6,
}
local S = {
enabled=false, status="OFF",
bridge=nil, lastBridgeCheck=0,
lastStepKey=nil, target=nil,
forward=false,
mountAttempts=0, mountTime=0, mountDisabled=false,
flightDisabled=false,
takeoffAttempts=0, takeoffPhase=0, takeoffTime=0,
recoveryCount=0, recovery=nil, recoveryUntil=0,
detour=nil, nextSide=1,
lastRecovery=0,
progressDist=nil, progressTime=0,
lastRay=0,
groundZ=nil, groundZTime=0,
finalLanding=false,
descending=false,
lastSurge=0,
interactMode=false,
interactCandidate=nil,
interactCandidates=nil,
interactIndex=1,
interactTime=0,
interactAttempts=0,
triedObjects={},
}
local F = {}
local function now() return type(GetTime)=="function" and GetTime() or 0 end
local function log(x) print(PREFIX..tostring(x)) end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b else return v end end
local function hw()
if type(WGG.LastHardwareAction)=="function" then
pcall(WGG.LastHardwareAction, now()*1000)
end
end
local function unwrap(v)
if type(WGG.SecretUnwrap)=="function" then
local ok,x=pcall(WGG.SecretUnwrap,v)
if ok then return x end
end
return v
end
local function load(code,name)
if type(WGG.LoadString)~="function" then return nil,"WGG.LoadString unavailable" end
local fn=WGG.LoadString(code,name)
if type(fn)~="function" then return nil,tostring(fn) end
local ok,res=pcall(fn)
if not ok then return nil,tostring(res) end
return res
end
local function compile()
if F.forwardStart then return true end
local defs={
forwardStart={"return function() if type(MoveForwardStart)~='function' then error('MoveForwardStart unavailable') end MoveForwardStart() end","@FTA_forwardStart"},
forwardStop={"return function() if type(MoveForwardStop)~='function' then error('MoveForwardStop unavailable') end MoveForwardStop() end","@FTA_forwardStop"},
jumpStart={"return function() if type(JumpOrAscendStart)~='function' then error('JumpOrAscendStart unavailable') end JumpOrAscendStart() end","@FTA_jumpStart"},
ascendStop={"return function() if type(AscendStop)~='function' then error('AscendStop unavailable') end AscendStop() end","@FTA_ascendStop"},
descendStart={"return function() if type(DescendStart)~='function' then error('DescendStart unavailable') end DescendStart() end","@FTA_descendStart"},
descendStop={"return function() if type(DescendStop)~='function' then error('DescendStop unavailable') end DescendStop() end","@FTA_descendStop"},
summon={"return function() if not C_MountJournal or type(C_MountJournal.SummonByID)~='function' then error('SummonByID unavailable') end C_MountJournal.SummonByID(0) end","@FTA_summon"},
mounted={"return function() if type(IsMounted)~='function' then return false end return IsMounted() end","@FTA_mounted"},
flying={"return function() if type(IsFlying)~='function' then return false end return IsFlying() end","@FTA_flying"},
flyable={"return function() if type(IsFlyableArea)~='function' then return false end return IsFlyableArea() end","@FTA_flyable"},
surge={"return function() if type(CastSpellByName)~='function' then error('CastSpellByName unavailable') end CastSpellByName('Surge Forward') end","@FTA_surge"},
}
for k,v in pairs(defs) do
local fn,err=load(v[1],v[2])
if not fn then return false,k..": "..tostring(err) end
F[k]=fn
end
return true
end
local function protected(fn,...)
if type(fn)~="function" then return false,"missing function" end
hw()
if type(WGG.CallProtected)=="function" then
local ok,s,a,b,c=pcall(WGG.CallProtected,fn,...)
if not ok then return false,tostring(s) end
if s then return true,a,b,c end
return false,tostring(a or "CallProtected false")
end
local ok,a,b,c=pcall(fn,...)
if ok then return true,a,b,c end
return false,tostring(a)
end
local function pbool(fn)
local ok,v=protected(fn)
return ok and (unwrap(v)==true or unwrap(v)==1)
end
local function isMounted() if not F.mounted then compile() end return F.mounted and pbool(F.mounted) or false end
local function isFlying() if not F.flying then compile() end return F.flying and pbool(F.flying) or false end
local function isFlyable() if not F.flyable then compile() end return F.flyable and pbool(F.flyable) or false end
local function startForward()
if S.forward then return true end
local ok,err=compile(); if not ok then return false,err end
ok,err=protected(F.forwardStart)
if ok then S.forward=true end
return ok,err
end
local function stopForward()
if not F.forwardStop then compile() end
if F.forwardStop then protected(F.forwardStop) end
S.forward=false
end
local function startDescend()
if S.descending then return true end
local ok,err=compile(); if not ok then return false,err end
if not F.descendStart then return false,"DescendStart unavailable" end
local d,de=protected(F.descendStart)
if d then S.descending=true end
return d,de
end
local function stopDescend()
if S.descending and F.descendStop then protected(F.descendStop) end
S.descending=false
end
local function fullStop()
stopForward()
if F.ascendStop then protected(F.ascendStop) end
stopDescend()
if type(WGG.SetPitch)=="function" then pcall(WGG.SetPitch,0) end
end
local function bridge()
if S.bridge and now()-S.lastBridgeCheck<2 then return S.bridge end
S.lastBridgeCheck=now()
if type(FTA_WGG_Bridge)=="table" then S.bridge=FTA_WGG_Bridge
elseif type(_G)=="table" and type(_G.FTA_WGG_Bridge)=="table" then S.bridge=_G.FTA_WGG_Bridge
elseif type(WGG.LoadString)=="function" then
local fn=WGG.LoadString("return _G and _G.FTA_WGG_Bridge","@FTA_bridge")
if type(fn)=="function" then
local ok,v=pcall(fn)
if ok and type(v)=="table" then S.bridge=v end
end
end
return S.bridge
end
local function currentStep()
local b=bridge()
if not b or type(b.GetCurrent)~="function" then return nil,"NO FTA BRIDGE" end
local ok,d,e=pcall(b.GetCurrent)
if not ok then return nil,"BRIDGE ERROR: "..tostring(d) end
if not d then return nil,tostring(e or "NO ACTIVE FTA STEP") end
return d
end
local function stepKey(d)
local t=d and d.target
return table.concat({
tostring(d and d.routeId),tostring(d and d.moduleId),
tostring(d and d.stepIndex),tostring(d and d.segmentIndex),
tostring(d and d.kind),tostring(t and t.mapID),
tostring(t and t.x01),tostring(t and t.y01)
},"|")
end
local function call(func,...)
if type(func)~="function" then return false end
local ok,a,b,c=pcall(func,...)
if ok then return true,a,b,c end
if type(WGG.CallProtected)=="function" then
local pok,s,x,y,z=pcall(WGG.CallProtected,func,...)
if pok and s then return true,x,y,z end
end
return false
end
local function xy(v)
if not v then return nil end
if type(v.GetXY)=="function" then
local ok,x,y=pcall(v.GetXY,v); if ok then return x,y end
end
if type(v.x)=="number" and type(v.y)=="number" then return v.x,v.y end
end
local function mapToWorld(mapID,x01,y01)
if not(C_Map and C_Map.GetWorldPosFromMapPos) or type(CreateVector2D)~="function" then
return nil,"map conversion unavailable"
end
local ok,worldMap,pos=call(C_Map.GetWorldPosFromMapPos,mapID,CreateVector2D(x01,y01))
if not ok or not pos then return nil,"map -> world failed" end
local x,y=xy(pos)
if type(x)~="number" or type(y)~="number" then return nil,"world XY unreadable" end
return {worldMapID=worldMap,x=x,y=y}
end
local function resolve(d)
local t=d and d.target
if not t or type(t.mapID)~="number" or type(t.x01)~="number" or type(t.y01)~="number" then
return nil,"FTA STEP HAS NO TARGET"
end
local w,e=mapToWorld(t.mapID,t.x01,t.y01)
if not w then return nil,string.upper(e) end
w.radius=math.max(tonumber(t.radius) or 6,CFG.minArrivalRadius)
w.kind=d.kind
return w
end
local function playerPos()
if type(WGG.GetPlayerPosition)~="function" then return nil end
local ok,x,y,z,s=pcall(WGG.GetPlayerPosition)
if ok and s~=false and type(x)=="number" and type(y)=="number" and type(z)=="number" then return x,y,z end
end
local function dist2(x1,y1,x2,y2)
local dx,dy=x2-x1,y2-y1
return math.sqrt(dx*dx+dy*dy)
end
local function ray(...)
if type(WGG.Raycast)~="function" then return false end
local ok,h,x,y,z,d=pcall(WGG.Raycast,...)
if not ok then return false end
return h==true,x,y,z,d
end
local function groundZ(x,y,refZ)
if type(WGG.Raycast)~="function" then return nil end
local samples={{0,0},{3,0},{-3,0},{0,3},{0,-3}}
local low=nil
for _,o in ipairs(samples) do
local sx,sy=x+o[1],y+o[2]
local h,_,_,z=ray(sx,sy,refZ+450,sx,sy,refZ-900)
if h and type(z)=="number" and (not low or z<low) then low=z end
end
return low
end
local function blocked(px,py,pz,ax,ay,az,maxD,flying)
if type(WGG.Raycast)~="function" then return false end
if flying then
local dx,dy,dz=ax-px,ay-py,az-pz
local l=math.sqrt(dx*dx+dy*dy+dz*dz)
if l<0.01 then return false end
dx,dy,dz=dx/l,dy/l,dz/l
local sx,sy,sz=px,py,pz+1.5
local ex,ey,ez=sx+dx*maxD,sy+dy*maxD,sz+dz*maxD
local h,_,_,_,d=ray(sx,sy,sz,ex,ey,ez)
return h and type(d)=="number" and d>1.0 and d<=maxD,d
end
local dx,dy=ax-px,ay-py
local l=math.sqrt(dx*dx+dy*dy)
if l<0.01 then return false end
dx,dy=dx/l,dy/l
local ex,ey=px+dx*maxD,py+dy*maxD
local heights={1.5,3.5}
for i=1,#heights do
local z=pz+heights[i]
local h,_,_,_,d=ray(px,py,z,ex,ey,z)
if h and type(d)=="number" and d>0.8 and d<=maxD then
return true,d
end
end
return false
end
local function face(x,y,z)
if type(WGG.SetFacing)~="function" then return false,"SetFacing unavailable" end
local ok,s=pcall(WGG.SetFacing,x,y,z)
if not ok then return false,tostring(s) end
return s~=false,s==false and "SetFacing false" or nil
end
local function pitch(a)
if type(WGG.SetPitch)=="function" then pcall(WGG.SetPitch,a) end
end
local function facing()
if type(WGG.GetFacing)=="function" then
local ok,v=pcall(WGG.GetFacing,"player")
if ok and type(v)=="number" then return v end
end
return 0
end
local function detour(px,py,pz,tx,ty,side)
local dx,dy=tx-px,ty-py
local l=math.sqrt(dx*dx+dy*dy)
if l<0.01 then
local f=facing(); dx,dy=math.cos(f),math.sin(f); l=1
end
dx,dy=dx/l,dy/l
return {
x=px+dx*CFG.detourForward+(-dy*side)*CFG.detourSide,
y=py+dy*CFG.detourForward+( dx*side)*CFG.detourSide,
z=pz
}
end
local function flightAim(px,py,pz,t,d)
if not S.groundZ then return t.x,t.y,pz+8 end
local z
if d>CFG.approachDistance then z=S.groundZ+CFG.cruiseHeight
else
local f=clamp(d/CFG.approachDistance,0,1)
z=S.groundZ+CFG.nearGroundHeight+(CFG.cruiseHeight-CFG.nearGroundHeight)*f
end
local x,y=t.x,t.y
local alt=pz-S.groundZ
if d<12 and alt>CFG.nearGroundHeight+3 then
local dx,dy=t.x-px,t.y-py
local l=math.sqrt(dx*dx+dy*dy)
if l<0.5 then local f=facing(); dx,dy=math.cos(f),math.sin(f); l=1 end
dx,dy=dx/l,dy/l
x,y=t.x+dx*22,t.y+dy*22
z=S.groundZ+4
end
return x,y,z
end
local function moveGround(px,py,pz,t)
local ax,ay,az=t.x,t.y,pz
if S.recovery=="DETOUR" and S.detour then ax,ay,az=S.detour.x,S.detour.y,S.detour.z end
local ok,e=face(ax,ay,az); if not ok then return false,e end
pitch(0)
local m,me=startForward(); if not m then return false,me end
return true,nil,ax,ay,az
end
local function moveFly(px,py,pz,t,d)
local alt=S.groundZ and (pz-S.groundZ) or nil
if S.finalLanding then
face(t.x,t.y,S.groundZ or pz)
stopForward()
startDescend()
pitch(math.rad(-45))
return true,nil,t.x,t.y,(S.groundZ or pz)-5
end
if alt and d<=CFG.finalLandingDistance and alt<=CFG.finalLandingAltitude then
S.finalLanding=true
log(string.format("FINAL LANDING: %.0f yd away, %.1f yd above terrain",d,alt))
face(t.x,t.y,S.groundZ or pz)
stopForward()
startDescend()
pitch(math.rad(-45))
return true,nil,t.x,t.y,(S.groundZ or pz)-5
end
local ax,ay,az=flightAim(px,py,pz,t,d)
if S.recovery=="FLY_DETOUR" and S.detour then
stopDescend()
ax,ay=S.detour.x,S.detour.y
az=math.max(az,pz+10)
elseif S.recovery=="CLIMB" then
stopDescend()
az=math.max(az,pz+35)
elseif alt and d<=CFG.landingDistance then
startDescend()
az=(S.groundZ or az)+1
else
stopDescend()
end
local ok,e=face(ax,ay,az); if not ok then return false,e end
local h=math.max(dist2(px,py,ax,ay),0.01)
local p=math.atan2(az-pz,h)
if S.recovery=="CLIMB" then
p=CFG.recoveryPitch
elseif alt and d<=CFG.landingDistance then
p=math.min(p,math.rad(-28))
end
pitch(clamp(p,CFG.maxPitchDown,CFG.maxPitchUp))
local m,me=startForward(); if not m then return false,me end
return true,nil,ax,ay,az
end
local function clearRecovery()
S.recovery=nil; S.recoveryUntil=0; S.detour=nil
end
local function recover(fly,px,py,pz,t,why)
local n=now()
if n-S.lastRecovery<CFG.obstacleCooldown then return end
S.lastRecovery=n
S.recoveryCount=S.recoveryCount+1
if S.recoveryCount>CFG.maxRecoveries then
S.enabled=false; fullStop(); S.status="TOO MANY OBSTACLES - AUTO OFF"
log("Auto-off after too many recovery attempts.")
return
end
if fly and S.recoveryCount%2==1 then
S.recovery="CLIMB"; S.recoveryUntil=n+CFG.climbSeconds; S.detour=nil
pitch(CFG.recoveryPitch)
log("Recovery #"..S.recoveryCount..": CLIMB ("..why..")")
else
local side=S.nextSide; S.nextSide=-S.nextSide
S.detour=detour(px,py,pz,t.x,t.y,side)
S.recovery=fly and "FLY_DETOUR" or "DETOUR"
S.recoveryUntil=n+CFG.detourSeconds
log("Recovery #"..S.recoveryCount..": "..(side>0 and "LEFT" or "RIGHT").." DETOUR ("..why..")")
end
S.progressDist=nil; S.progressTime=n
end
local function summon()
local ok,e=compile(); if not ok then return false,e end
fullStop()
return protected(F.summon)
end
local function resetTakeoff() S.takeoffPhase=0; S.takeoffTime=0 end
local function takeoff()
local n=now()
if isFlying() then
resetTakeoff(); pitch(CFG.takeoffPitch); startForward()
return true,"FLYING"
end
if S.takeoffAttempts>=CFG.maxTakeoffAttempts then
S.flightDisabled=true; resetTakeoff(); fullStop()
log("Takeoff failed repeatedly. Stopping instead of blindly running into city geometry.")
return false,"TAKEOFF FAILED"
end
local ok,e=compile(); if not ok then return false,e end
if S.takeoffPhase==0 then
fullStop(); pitch(CFG.takeoffPitch)
S.takeoffAttempts=S.takeoffAttempts+1
S.takeoffPhase=1; S.takeoffTime=n
local j,je=protected(F.jumpStart); if not j then return false,je end
return true,"TAKEOFF JUMP 1"
elseif S.takeoffPhase==1 then
if n-S.takeoffTime>=0.18 then protected(F.ascendStop); S.takeoffPhase=2; S.takeoffTime=n end
return true,"TAKEOFF JUMP 1"
elseif S.takeoffPhase==2 then
if n-S.takeoffTime>=0.35 then
local j,je=protected(F.jumpStart); if not j then return false,je end
S.takeoffPhase=3; S.takeoffTime=n
end
return true,"TAKEOFF JUMP 2"
elseif S.takeoffPhase==3 then
if n-S.takeoffTime>=0.12 then
protected(F.ascendStop); startForward(); pitch(CFG.takeoffPitch)
S.takeoffPhase=4; S.takeoffTime=n
end
return true,"TAKEOFF LAUNCH"
elseif S.takeoffPhase==4 then
startForward(); pitch(CFG.takeoffPitch)
if isFlying() then resetTakeoff(); log("Takeoff succeeded."); return true,"FLYING" end
if n-S.takeoffTime>=CFG.takeoffRetry then fullStop(); resetTakeoff() end
return true,"TAKEOFF..."
end
return true,"TAKEOFF..."
end
local panel=CreateFrame("Frame","FTA_DirectTravelV04Panel",UIParent)
panel:SetSize(300,78); panel:SetPoint("CENTER",UIParent,"CENTER",0,185)
panel:SetFrameStrata("DIALOG"); panel:SetMovable(true); panel:EnableMouse(true)
panel:RegisterForDrag("RightButton"); panel:SetClampedToScreen(true)
if type(panel.SetBackdrop)=="function" then
panel:SetBackdrop({
bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
tile=true,tileSize=16,edgeSize=12,
insets={left=3,right=3,top=3,bottom=3},
})
end
panel:SetScript("OnDragStart",function(self) self:StartMoving() end)
panel:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
local btn=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
btn:SetSize(275,28); btn:SetPoint("TOP",panel,"TOP",0,-7)
local stat=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
stat:SetPoint("TOP",btn,"BOTTOM",0,-5); stat:SetWidth(285); stat:SetJustifyH("CENTER")
local detail=panel:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
detail:SetPoint("TOP",stat,"BOTTOM",0,-2); detail:SetWidth(285); detail:SetJustifyH("CENTER")
local function ui(s,d)
S.status=s or S.status
btn:SetText(S.enabled and "FTA DIRECT TRAVEL: ON" or "FTA DIRECT TRAVEL: OFF")
stat:SetText(S.status)
detail:SetText(d or ("v"..VERSION))
end
local function normalizedKind(d)
return string.lower(tostring(d and d.kind or ""))
end
local function isPickupOrTurnin(d)
local k=normalizedKind(d)
return string.find(k,"pickup",1,true)
or string.find(k,"pick_up",1,true)
or string.find(k,"accept",1,true)
or string.find(k,"turnin",1,true)
or string.find(k,"turn_in",1,true)
or string.find(k,"turn",1,true)
end
local function objectKey(obj)
if not obj then return nil end
if type(WGG.ObjectGUID)=="function" then
local ok,g=pcall(WGG.ObjectGUID,obj)
if ok and g and tostring(g)~="0:0" then return tostring(g) end
end
return tostring(obj)
end
local function objectInfo(obj,px,py,pz,marker)
if not obj or type(WGG.ObjectPos)~="function" then return nil end
local ok,x,y,z=pcall(WGG.ObjectPos,obj)
if not ok or type(x)~="number" or type(y)~="number" or type(z)~="number" then
return nil
end
local name=nil
if type(WGG.ObjectName)=="function" then
local nok,n=pcall(WGG.ObjectName,obj)
if nok then name=n end
end
name=tostring(name or "")
if name=="" or name=="nil" then return nil end
local id=0
if type(WGG.ObjectID)=="function" then
local iok,v=pcall(WGG.ObjectID,obj)
if iok and type(v)=="number" then id=v end
end
local guid=objectKey(obj)
if type(WGG.ObjectGUID)=="function" then
local pok,pg=pcall(WGG.ObjectGUID,"player")
if pok and pg and tostring(pg)==tostring(guid) then return nil end
end
local pd=math.sqrt((x-px)^2+(y-py)^2+(z-pz)^2)
local md=math.sqrt((x-marker.x)^2+(y-marker.y)^2)
if pd>CFG.scanPlayerRadius or md>CFG.scanMarkerRadius then
return nil
end
return {
obj=obj,
key=guid,
id=id,
name=name,
x=x,y=y,z=z,
playerDist=pd,
markerDist=md,
score=(md*2.0)+pd,
}
end
local function scanInteractionCandidates(px,py,pz,marker)
if type(WGG.GetObjectCount)~="function"
or type(WGG.GetObjectWithIndex)~="function" then
return {}, "OBJECT MANAGER ENUMERATION UNAVAILABLE"
end
local ok,total=pcall(WGG.GetObjectCount)
if not ok or type(total)~="number" then
return {}, "OBJECT COUNT FAILED"
end
local list={}
for i=0,total-1 do
local ook,obj=pcall(WGG.GetObjectWithIndex,i)
if ook and obj then
local info=objectInfo(obj,px,py,pz,marker)
if info and not S.triedObjects[info.key] then
list[#list+1]=info
end
end
end
table.sort(list,function(a,b)
if a.score==b.score then return a.playerDist<b.playerDist end
return a.score<b.score
end)
while #list>CFG.maxInteractCandidates do
table.remove(list)
end
return list
end
local function beginInteractionSearch(px,py,pz,marker,d)
if not isPickupOrTurnin(d) then return false end
local candidates,err=scanInteractionCandidates(px,py,pz,marker)
if #candidates==0 then
ui("ARRIVED - NO NPC FOUND",
tostring(err or "No live object close to FTA marker"))
return true
end
S.interactMode=true
S.interactCandidates=candidates
S.interactIndex=1
S.interactCandidate=candidates[1]
S.interactTime=0
S.interactAttempts=0
local c=S.interactCandidate
log(string.format(
"Live target candidate: %s | ID %s | player %.1f yd | marker %.1f yd",
tostring(c.name),tostring(c.id),c.playerDist,c.markerDist
))
return true
end
local function nextInteractionCandidate()
if S.interactCandidate and S.interactCandidate.key then
S.triedObjects[S.interactCandidate.key]=true
end
S.interactIndex=(S.interactIndex or 1)+1
S.interactCandidate=
S.interactCandidates and S.interactCandidates[S.interactIndex] or nil
S.interactTime=0
if S.interactCandidate then
local c=S.interactCandidate
log(string.format(
"Trying next live candidate: %s | ID %s | player %.1f yd | marker %.1f yd",
tostring(c.name),tostring(c.id),c.playerDist,c.markerDist
))
return true
end
S.interactMode=false
S.interactCandidates=nil
ui("ARRIVED - INTERACTION FAILED",
"No candidate advanced the FTA step")
return false
end
local function updateInteraction(px,py,pz,d)
local c=S.interactCandidate
if not S.interactMode or not c then return false end
local ok,x,y,z=pcall(WGG.ObjectPos,c.obj)
if not ok or type(x)~="number" or type(y)~="number" or type(z)~="number" then
nextInteractionCandidate()
return true
end
c.x,c.y,c.z=x,y,z
c.playerDist=math.sqrt((x-px)^2+(y-py)^2+(z-pz)^2)
if c.playerDist>CFG.interactDistance then
stopDescend()
pitch(0)
local fok,fe=face(c.x,c.y,c.z)
if not fok then
log("Candidate facing failed: "..tostring(fe))
nextInteractionCandidate()
return true
end
local mok,me=startForward()
if not mok then
log("Candidate approach failed: "..tostring(me))
nextInteractionCandidate()
return true
end
ui("APPROACHING NPC | "..tostring(d.kind or "STEP"),
string.format("%s | ID %s | %.1f yd",
tostring(c.name),tostring(c.id),c.playerDist))
return true
end
fullStop()
if S.interactTime==0 then
if type(WGG.ObjectInteract)~="function" then
ui("OBJECTINTERACT UNAVAILABLE")
S.interactMode=false
return true
end
local iok,res=pcall(WGG.ObjectInteract,c.obj)
S.interactTime=now()
S.interactAttempts=S.interactAttempts+1
log(string.format(
"Interact -> %s | ID %s | result=%s",
tostring(c.name),tostring(c.id),tostring(iok and res)
))
ui("INTERACTING | "..tostring(d.kind or "STEP"),
string.format("%s | ID %s",tostring(c.name),tostring(c.id)))
return true
end
if now()-S.interactTime>=CFG.interactRetryDelay then
nextInteractionCandidate()
else
ui("WAITING FOR FTA | "..tostring(d.kind or "STEP"),
string.format("%s | ID %s",tostring(c.name),tostring(c.id)))
end
return true
end
local function trySurgeForward(dist,fly)
if not fly or S.finalLanding or S.recovery or S.descending then return end
if dist<CFG.surgeMinDistance or dist<=CFG.surgeStopDistance then return end
if now()-S.lastSurge<CFG.surgeInterval then return end
if not F.surge then return end
protected(F.surge)
S.lastSurge=now()
log("Surge Forward attempted at "..string.format("%.0f",dist).." yd.")
end
local function resetStep()
fullStop()
S.target=nil
S.mountAttempts=0; S.mountTime=0; S.mountDisabled=false
S.flightDisabled=false; S.takeoffAttempts=0; resetTakeoff()
S.recoveryCount=0; clearRecovery(); S.nextSide=1
S.progressDist=nil; S.progressTime=now()
S.groundZ=nil; S.groundZTime=0
S.finalLanding=false; S.descending=false
S.lastSurge=0
S.interactMode=false
S.interactCandidate=nil
S.interactCandidates=nil
S.interactIndex=1
S.interactTime=0
S.interactAttempts=0
S.triedObjects={}
end
local function disable(reason)
S.enabled=false; fullStop(); clearRecovery(); ui(reason or "OFF")
log("Direct travel OFF"..(reason and (" - "..reason) or ""))
end
local function enable()
S.enabled=true; resetStep(); ui("STARTING..."); log("Direct travel ON")
end
btn:SetScript("OnClick",function() if S.enabled then disable("OFF") else enable() end end)
SLASH_FTADIRECT2_1="/ftadirect4"
SlashCmdList.FTADIRECT2=function() if S.enabled then disable("OFF") else enable() end end
ui("OFF")
local elapsed=0
local frame=CreateFrame("Frame")
frame:SetScript("OnUpdate",function(_,dt)
if not S.enabled then return end
elapsed=elapsed+dt; if elapsed<CFG.tick then return end; elapsed=0
local n=now()
if type(UnitIsDeadOrGhost)=="function" and UnitIsDeadOrGhost("player") then fullStop(); ui("DEAD - PAUSED"); return end
if type(UnitAffectingCombat)=="function" and UnitAffectingCombat("player") then fullStop(); ui("COMBAT - PAUSED"); return end
local d,e=currentStep()
if not d then fullStop(); ui(e or "NO FTA STEP"); return end
local key=stepKey(d)
if key~=S.lastStepKey then
S.lastStepKey=key; resetStep()
log("New FTA step: "..tostring(d.kind or "-").." | "..tostring(d.text or d.stepText or "-"))
end
local t,te=resolve(d)
if not t then fullStop(); ui(te or "NO TARGET"); return end
S.target=t
local px,py,pz=playerPos()
if not px then fullStop(); ui("NO PLAYER POSITION"); return end
local dist=dist2(px,py,t.x,t.y)
if not S.groundZ or n-S.groundZTime>=4 then
S.groundZ=groundZ(t.x,t.y,pz); S.groundZTime=n
end
local fly=isFlying()
local mounted=isMounted()
local alt=S.groundZ and (pz-S.groundZ) or nil
if S.interactMode then
if updateInteraction(px,py,pz,d) then return end
end
if S.finalLanding then
if (not fly) or (alt and alt<=CFG.landedAltitude) then
stopDescend()
stopForward()
pitch(0)
S.finalLanding=false
fly=isFlying()
log("Landing complete; switching to ground approach.")
else
face(t.x,t.y,S.groundZ or pz)
stopForward()
startDescend()
pitch(math.rad(-45))
ui("LANDING | "..tostring(d.kind or "STEP"),
string.format("%.0f yd | dZ %.1f",dist,alt or -1))
return
end
end
if dist<=t.radius and (not fly or not alt or alt<=CFG.nearGroundHeight+2) then
fullStop()
if isPickupOrTurnin(d) then
if not S.interactMode then
beginInteractionSearch(px,py,pz,t,d)
end
if S.interactMode then
updateInteraction(px,py,pz,d)
end
return
end
ui(string.format("ARRIVED %.1f yd | %s",dist,tostring(d.kind or "STEP")),
alt and string.format("terrain dZ %.1f",alt) or "ground Z unavailable")
return
end
if S.recovery and n>=S.recoveryUntil then
clearRecovery(); S.progressDist=dist; S.progressTime=n
log("Recovery finished; FTA target reacquired.")
end
if dist>=CFG.mountDistance and not mounted and not S.mountDisabled then
if S.mountTime==0 or n-S.mountTime>=CFG.mountRetry then
if S.mountAttempts>=CFG.maxMountAttempts then
S.mountDisabled=true; log("Mount failed repeatedly; foot fallback.")
else
S.mountAttempts=S.mountAttempts+1; S.mountTime=n
local ok,me=summon()
if ok then ui("MOUNTING...",string.format("attempt %d/%d | %.0f yd",S.mountAttempts,CFG.maxMountAttempts,dist)); return
else log("Mount error: "..tostring(me)) end
end
else
fullStop(); ui("MOUNTING...",string.format("%.0f yd",dist)); return
end
end
mounted=isMounted(); fly=isFlying()
local wantsFly=mounted and dist>=CFG.flyDistance and not S.flightDisabled and isFlyable()
if wantsFly and not fly then
local ok,ts=takeoff()
if not ok then
S.flightDisabled=true; resetTakeoff(); log("Takeoff API error: "..tostring(ts))
else
ui(ts,string.format("%.0f yd | attempt %d/%d",dist,S.takeoffAttempts,CFG.maxTakeoffAttempts))
return
end
end
fly=isFlying()
trySurgeForward(dist,fly)
local ok,err,ax,ay,az
if fly then ok,err,ax,ay,az=moveFly(px,py,pz,t,dist)
else ok,err,ax,ay,az=moveGround(px,py,pz,t) end
if not ok then disable("MOVE/FACING FAILED"); log("Movement error: "..tostring(err)); return end
if not S.recovery and n-S.lastRay>=CFG.raycastInterval then
S.lastRay=n
local b,bd=blocked(px,py,pz,ax,ay,az,fly and CFG.obstacleFly or CFG.obstacleGround,fly)
if b then recover(fly,px,py,pz,t,"raycast "..string.format("%.1f yd",bd)) end
end
if not S.recovery then
if not S.progressDist then S.progressDist=dist; S.progressTime=n
elseif n-S.progressTime>=CFG.progressWindow then
local progress=S.progressDist-dist
if progress<CFG.minProgress then
recover(fly,px,py,pz,t,string.format("stuck %.1f yd progress",progress))
else
S.progressDist=dist; S.progressTime=n
if S.recoveryCount>0 and progress>8 then S.recoveryCount=math.max(0,S.recoveryCount-1) end
end
end
end
local mode
if S.recovery=="CLIMB" then mode="OBSTACLE - CLIMB"
elseif S.recovery=="FLY_DETOUR" then mode="OBSTACLE - FLY DETOUR"
elseif S.recovery=="DETOUR" then mode="OBSTACLE - GROUND DETOUR"
elseif S.finalLanding then mode="LANDING"
elseif fly and dist<=CFG.landingDistance then mode="DESCENDING"
elseif fly and dist<=CFG.approachDistance then mode="FLY APPROACH"
elseif fly then mode="FLYING"
elseif mounted then mode="MOUNTED GROUND"
else mode="DIRECT GROUND" end
local info={string.format("%.0f yd",dist)}
if alt then info[#info+1]=string.format("dZ %.0f",alt) end
if type(WGG.DragonSpeed)=="function" then
local so,sp=pcall(WGG.DragonSpeed)
if so and type(sp)=="number" and sp>0 then info[#info+1]=string.format("dragon %.1f",sp) end
end
if S.recoveryCount>0 then info[#info+1]="recover "..S.recoveryCount end
ui(mode.." | "..tostring(d.kind or "STEP"),table.concat(info," | "))
end)
log("Loaded v"..VERSION..". Default OFF.")
log("No navigation server is used.")
log("Keep older FTA movement scripts OFF while testing.")
log("v0.4: live pickup/turn-in scan + ObjectInteract + controlled Surge Forward enabled.")
