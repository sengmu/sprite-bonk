# C23 补证挖掘 addendum（2026-11-07）

只读静态补证；本单唯一写入为本文件，未改代码、pack 或关账裁定，未构建/运行游戏，未入包 reference。

**原料位置核对**：`reference/orig_assets/` 实际只有素材/数据及 INVENTORY，没有 JS bundle。本次只读使用 pack 所引的既有本地镜像：

- main：`/home/hatch/workspace/pokebonk-rea/scripts_out/files/origins/3be62a71e6b7643af0182c742f1dbf8e5693334fcb4fae70524563ae5a92cece/assets/main-CkI7dQhz-mvml8e65.js`
- news：同目录 `news-BfmMIm3P-mvml8e65.js`。

偏移统一为 **UTF-8 解码后的 Unicode 字符、从 0 起算**，不是 byte 或 UTF-16 索引。pack 偏移作为检索锚点，本单标注精确连续原文起止。JS 块未经改写/格式化。

| chunk | bytes | 字符数 | SHA-256 |
|---|---:|---:|---|
| main | 2154272 | 2149687 | `4b4a76ddd47d60167f4a330250cee58f036dc68d2efa692aaecd9638249d2d7e` |
| news | 165774 | 164568 | `736c30d857e23cc3b424789981230ae97408fa66d17c3e8699ef9191e067f2fc` |

三节共同表值/别名：main 的 Ze ← news export Rn ← news local Vt。

**[main] @719–727（右端不含）**

```js
Rn as Ze
```

**[news] @163275–163283（右端不含）**

```js
Vt as Rn
```

**[news] @89283–89592（右端不含）**

```js
Vt={hp:[1,1.4,1.9],dmg:[1,1.42,1.96],speed:[1,1.08,1.16],amount:[1,1.3,1.6],kills:[1,1.25,1.5],level:[1,1.5,1.8],cap:[1,1.15,1.3],elite:[0,.04,.08],events:[1,1.2,1.4],early:[0,15,30],tele:[1,.92,.85],fury:[.5,.55,.6],escorts:[0,1,2],wound:[4,5,6],strike:[1,1.2,1.4],late:[1,1.12,1.25],alphaCap1:[.15,.25,.25]}
```

## 1. woundT 施加、生命周期及消费者 — 全证

### 1.1 赋值/刷新、到期

**[main] @817990–818220（右端不含）**

```js
woundT=0;woundPopT=0;wound(e){this.dead||(this.woundT<=0&&this.woundPopT<=0&&(this.woundPopT=3,this.run.ui.popup(this.pos.x,this.pos.y+2.9,this.pos.z,c(`¡Herida! Curas la mitad`),`#ff6a8a`,1)),this.woundT=Math.max(this.woundT,e))}
```

初始 0；活着时 `wound(e)` 写 `max(旧剩余时长,e)`，**不相加**。同 tier 命中刷新到 4/5/6 秒，较短时长不能缩短旧伤。仅当旧 woundT<=0 且 woundPopT<=0 才弹提示并设 3 秒弹字冷却；冷却不阻止刷新。dead 时方法整体无效。

**[main] @837381–837638（右端不含）**

```js
update(e){let t=this.run,n=t.input,r=t.terrain;if(this.dead){this.vel.set(0,0,0),this.crowdX=this.crowdZ=this.kx=this.kz=0,t.coop&&(this.flash=Math.max(0,this.flash-e*5),this.hurtT-=e);return}let i=this.stats;this.iframes-=e,this.woundT-=e,this.woundPopT-=e
```

活着的 update 每帧 `woundT-=dt`，**不钳制为 0**，可以变负，`<=0` 即失效。dead 提前 return，死亡期间不递减。全 main 的 woundT 共 8 处匹配：heal、字段初始化、wound 条件、Math.max 左右两次、update、shield regen、HUD；没有另一个清零/驱散/换区重置写入。

### 1.2 全部施加点：三个 wrapper

**[main] @868842–868942（右端不含）**

```js
Wy=.08,Gy=e=>Ze.wound[e.tier]??4,Ky=.5,qy=(e,t)=>({floor:t>=.3?t:t*(Ze.strike[e.tier]??1),evade:Ky})
```

**[main] @871823–872056（右端不含）**

```js
hurt(e,t=0,n=this.type){if(this.dead)return;let r=this.run.player,i=t>=.3,a=t<0?0:Math.max(t,Wy);r.hurt(this.E.dmg[this.i]*e*this.run.diff.enemyDamage,n,-1,NaN,NaN,!1,i?.6:.34,this.i,a?qy(this.run,a):{})&&t>=0&&r.wound(Gy(this.run))}
```

A：传奇 kit 基类 Yy.hurt。只有 player.hurt 返回 true 且 t>=0 才 wound；默认 t=0 也施伤，t<0 同时关闭 floor 和 wound；t>=.3 用 .6 cap，否则 .34。几何判定由调用者先完成。circle、line、特殊大招汇入该方法：

**[main] @872420–872503（右端不含）**

```js
let r=c.player.pos;(r.x-e)**2+(r.z-t)**2<n*n&&this.playerLow(l)&&this.hurt(i),s?.()
```

**[main] @873239–873320（右端不含）**

```js
o>0&&p<i+u.player.radius&&this.playerLow(this.groundY(n.x,n.z),1.3)&&this.hurt(o)
```

**[main] @875075–875089（右端不含）**

```js
this.hurt(i,a)
```

其余直接调用：@882393 dash，@883636 sweep，@887887 `hurt(2.8,.4)`，@891044 ground，@894742 波 ``hurt(r.mul,r.minFrac,`ground`)``，@901236 ground，@903824 mine，@910962 fire dive，@911703 fire ring，@913104 fire，@920895 `hurt(3,.4)`，@922377 psychic wave。均由上面的 wrapper 控制伤势。明确反例 psychic pull：

**[main] @923615–923659（右端不含）**

```js
this.pullHurtT=.4,this.hurt(.7,-1,`psychic`)
```

该路径 t=-1，有伤害但无 wound。Yy.shot 走 Hostile|Capped 弹体路径（§2），也不调用 Yy.hurt。

**[main] @996940–997113（右端不含）**

```js
strike(e,t,n=Wy){let r=this.run,i=r.player,a=r.enemies;return i.hurt(a.dmg[e]*t*r.diff.enemyDamage,a.typesOf(e)[0],-1,a.x[e],a.z[e],!1,.34,e,qy(r,n))?(i.wound(Gy(r)),!0):!1}
```

**[main] @938624–938680（右端不含）**

```js
strike(e,t){return this.live&&this.B.strike(this.i,e,t)}
```

B：boss 管理器 Nb.strike；包括守护者动作和 ub 专用机制的委托。player.hurt 返回 true 才 wound，无 HP 实降条件。默认 floor=.08、cap=.34、evade=.5（§2）。

**[main] @1028661–1028840（右端不含）**

```js
strike(e,t,n=Wy){let r=this.run,i=r.player,a=r.enemies,o=e.i;return i.hurt(a.dmg[o]*t*r.diff.enemyDamage,a.typesOf(o)[0],-1,a.x[o],a.z[o],!1,.34,o,qy(r,n))?(i.wound(Gy(r)),!0):!1}
```

C：ix miniboss 管理器（totem/summoner）strike；同 B，仅从 e.i 取索引。charge/slams/leap 等经此入口，不能限缩成 guardian-only。

全 main 的 `.wound(`、`Gy(` 各只有上述 3 个调用。普通身体接触、Hostile 弹体的 hurt 调用均无 wound；Boss/Capped 标志自身不会施伤势。

### 1.3 命中成功及全盾挡

**[main] @818329–818523（右端不含）**

```js
hurt(e,t,n,r=NaN,i=NaN,a=!1,o=0,s=n,l={}){let u=this.run;if(a&&this.ability===`magic-guard`||this.iframes>0||this.dead||this.invisT>0||u.frozen||u.regionCleared||u.state===`transition`)return!1;
```

**[main] @818523–819427（右端不含）**

```js
if(F.chance(this.stats.evasion*(l.evade??1)))return u.stats.dodges++,this.iframes=.25,u.vfx.text.spawn(this.pos.x,this.pos.y+2.2,this.pos.z,`-`,11069695,.5),u.audio.dodge(),u.meta.count(`dodges`,1),this.ability===`steadfast-aura`&&(this.auraStacks=Math.min(5,this.auraStacks+1),this.auraT=4),this.ability===`shadow-tag`&&n>=0&&u.combat.hit(n,60,{type:`ghost`,cls:`physical`,fixed:!0}),n>=0&&this.stats.thorns>0&&this.vitamins.has(`sticky-barb`)&&this.thorns(n),L_(this.ability)?.onDodge?.(u,this,n),!1;let d=this.items.get(`guard-spec`);if(d&&this.guardT<=0&&!a)return this.guardT=14-3*(d-1),u.stats.dodges++,u.meta.count(`dodges`,1),this.iframes=.4,u.vfx.ring(this.pos.x,this.pos.y+.1,this.pos.z,2.2,10148095,.35,.3),u.vfx.burst(this.pos.x,this.pos.y+1.2,this.pos.z,14217471,12,4,I.Square,.4,.4),u.ui.popup(this.pos.x,this.pos.y+2.4,this.pos.z,c(`¡Protección!`),`#9ad8ff`,.8),u.audio.dodge(),!1;let f=e;
```

**[main] @820031–820382（右端不含）**

```js
if(this.shield>0){let e=Math.min(this.shield,f);this.shield-=e,f-=e}if(this.hp-=f,f>0&&(this.lastHit=typeof s==`object`?s:s>=0?Cp(u,s):{kind:a?`hazard`:u.sanctuary&&u.stage>=4?`legendary`:`other`,species:0}),u.ult?.onHurt(f/this.maxHp),p?.onHurt?.(u,this,f,n),this.iframes=.45,this.flash=1,this.hurtT=.3,this.pstat.sleep=0,this.noHitT=0,this.squash=.5
```

**[main] @822401–822451（右端不含）**

```js
this.hp=0,this.dead=!0,u.onPlayerDeath()}return!0}
```

免疫/状态门、evasion、guard-spec 全挡返回 false，不刷新 wound。overheal/shield 全吸收后 f=0，仍记账并返回 true，**会刷新 wound**。若命中致死，后续 wound 自身 dead 检查挡住写入；存活/复活分支依最终 alive 状态处理。noHitT 由 hurt 归零，与 wound 是两个独立计时。

### 1.4 除回盾减半外的消费者

**[main] @817244–817627（右端不含）**

```js
heal(e){if(e<=0||this.dead)return 0;let t=this.hp,n=(this.run.endless?qe(this.run.time/60):1)*(this.woundT>0?.5:1),r=e*this.stats.healing*n;this.hp=Math.min(this.maxHp,this.hp+r),this.hp>t&&this.run.meta.count(`healed`,this.hp-t),r>this.hp-t&&this.items.has(`fresh-water`)&&(this.freshStore=Math.min(this.maxHp*.4,this.freshStore+r-(this.hp-t)));let i=this.stats.overheal*this.maxHp;
```

**[main] @817856–817956（右端不含）**

```js
leech(e){let t=Math.min(e,this.leechBudget);t<=0||(this.leechBudget-=t,this.leechAcc+=this.heal(t))}
```

heal 的有效输入全式为 `r=e*stats.healing*(run.endless?qe(run.time/60):1)*(woundT>0?.5:1)`。进入 heal 的治疗及 leech 都减半；fresh-water 存储和 overheal 也基于减半后的 r。直接赋 hp 的恢复未证受该倍率，不可扩推。

**[main] @839123–839239（右端不含）**

```js
i.shieldMax>0&&this.noHitT>3&&(this.shield=Math.min(i.shieldMax,this.shield+i.shieldMax*.25*e*(this.woundT>0?.5:1)))
```

**[main] @2020068–2020109（右端不含）**

```js
n.hp.classList.toggle(`wound`,t.woundT>0)
```

另外两消费者为 shield regen 与 HUD wound class；未发现其他 woundT 消费者。woundPopT 只控制提示冷却。

### 可施工结论

- `duration=Ze.wound[tier]??4`；`woundT=max(woundT,duration)`；活着 update 做 `woundT-=dt`，以 `>0` 判有效；popup 冷却 3 秒。
- 三个 wrapper 在 hurt 成功后施加，Yy 另要求 t>=0；全盾挡仍成功，闪避/guard-spec 等 false 不成功。
- 回盾全式：`shield=min(shieldMax,shield+shieldMax*.25*dt*(woundT>0?.5:1))`，前置 `shieldMax>0 && noHitT>3`。
- 治疗输入全式：`r=e*stats.healing*(run.endless?qe(run.time/60):1)*(woundT>0?.5:1)`，然后沿 heal 的 HP/fresh-water/overheal 顺序；HUD 读 `woundT>0`。

## 2. strike 全公式及 scripts/ 对应 — 全证

### 2.1 flags 与两处分派

**[main] @321707–322203（右端不含）**

```js
R=function(e){return e[e.Elite=1]=`Elite`,e[e.Alpha=2]=`Alpha`,e[e.Boss=4]=`Boss`,e[e.Ranged=8]=`Ranged`,e[e.Flying=16]=`Flying`,e[e.Healer=32]=`Healer`,e[e.Shielder=64]=`Shielder`,e[e.Capture=128]=`Capture`,e[e.Charger=256]=`Charger`,e[e.Swarm=512]=`Swarm`,e[e.Stampede=1024]=`Stampede`,e[e.Shiny=2048]=`Shiny`,e[e.Totem=4096]=`Totem`,e[e.Summoner=8192]=`Summoner`,e[e.Treasure=16384]=`Treasure`,e[e.Object=32768]=`Object`,e[e.Remote=65536]=`Remote`,e[e.Classic=131072]=`Classic`,e}({}),bp=12290
```

**[main] @492146–492449（右端不含）**

```js
Zm=function(e){return e[e.Hostile=1]=`Hostile`,e[e.Homing=2]=`Homing`,e[e.Boomerang=4]=`Boomerang`,e[e.Arc=8]=`Arc`,e[e.Explode=16]=`Explode`,e[e.Wave=32]=`Wave`,e[e.Pull=64]=`Pull`,e[e.Mine=128]=`Mine`,e[e.Drain=256]=`Drain`,e[e.Spin=512]=`Spin`,e[e.Capped=1024]=`Capped`,e[e.Alpha=2048]=`Alpha`,e}({})
```

**[main] @335766–335781（右端不含）**

```js
let fe=b&12294;
```

**[main] @330971–331039（右端不含）**

```js
let S=!0;(this.frozen[m]>0||this.sleep[m]>0||this.stun[m]>0)&&(S=!1)
```

**[main] @336309–336657（右端不含）**

```js
let pe=te+n.radius;if(!(b&16512)&&D<pe&&Math.abs(this.y[m]-s)<this.hgt[m]+.8&&S){let e=b&2?Sp(t):fe?.25:0;n.hurt(this.dmg[m]*(this.charm[m]>0?.6:1)*t.diff.enemyDamage,this.typesOf(m)[0],m,NaN,NaN,!1,e,m,b&4?{floor:.05*(Ze.strike[t.tier]??1)}:{})&&(this.atkAnim[m]=.35,n.shove(y?(a-this.x[m])/D:T,y?(o-this.z[m])/D:E,b&12294?9:3+Math.min(4,te*2.5)))
```

第一处（pack @336528）是 jp.update **敌人身体接触 player**，不是 boss 技能 wrapper。条件：不含 mask16512（Capture|Treasure），距离 <enemyRadius+playerRadius，高差 <hgt+.8，可行动 S（无 frozen/sleep/stun）。原始伤害 D=`E.dmg[m]*(charm>0?.6:1)*diff.enemyDamage`。

floor：Boss flag4 才传 F=.05*(Ze.strike[tier]??1)，否则无。cap：先 Alpha flag2 → Sp(run)，否则 flags&12294（Alpha|Boss|Totem|Summoner）→.25，否则 0（不钳制）。Boss 体碰 cap=.25，totem/summoner cap=.25，alpha 用 Sp；复合 Alpha|Boss 时 Sp 优先且仍有 Boss floor。本路不施 wound。

**[main] @498491–499201（右端不含）**

```js
if(l&1){let e=t.sanctuary;if(e&&(e.hitCover(this.x[c],this.y[c],this.z[c],this.rad[c])||t.terrain.height(this.x[c],this.z[c])>this.y[c]+.4)){t.vfx.burst(this.x[c],this.y[c],this.z[c],this.color[c],4,3,I.Spark,.35,.25),this.remove(c);continue}let n=r.pos.x-this.x[c],i=r.pos.z-this.z[c],a=r.pos.y+.8-this.y[c];if(n*n+i*i<(this.rad[c]+r.radius)**2&&Math.abs(a)<1.5){let e=Math.hypot(this.vx[c],this.vz[c])||1,n=this.vx[c]/e,i=this.vz[c]/e;r.hurt(this.dmg[c]*t.diff.enemyDamage,this.types[c],-1,r.pos.x-n*3,r.pos.z-i*3,!1,l&1024?.15:l&2048?Sp(t):0,this.src[c]??-1,l&1024?{floor:.02*(Ze.strike[t.tier]??1)}:{})&&r.shove(n,i,3.5),t.vfx.burst(this.x[c],this.y[c],this.z[c],this.color[c],8,4),this.remove(c)}continue}
```

第二处（pack @499071）是 Qm.update **Hostile 弹体碰撞 player**：先掩体/地形拦截，再水平半径和 abs(高度差)<1.5 判定。D=projectile.dmg[c]*diff.enemyDamage。

Capped flag1024 时 F=.02*(Ze.strike[tier]??1)、C=.15；否则 Alpha flag2048 时无 floor、C=Sp(run)；否则无 floor/cap。两位同时有时 Capped 优先。成功才 shove，随后移除弹体；无 wound。不是所有 hostile 都有 .02 floor。

来源闭环：普通 ranged shot 只有 Hostile，alpha ranged 额外 Alpha；boss 两套 shot 明确 Hostile|Capped：

**[main] @494628–494954（右端不含）**

```js
enemyShot(e,t,n,r){let i=this.run.enemies,a=i.typesOf(e)[0],o=i.y[e]+i.hgt[e]*.6;this.fire({x:i.x[e],y:o,z:i.z[e],dx:t-i.x[e],dy:n-o,dz:r-i.z[e],speed:11,life:3,radius:.45,dmg:i.dmg[e]*.75,type:a,cls:`special`,flags:1|(i.flags[e]&R.Alpha?2048:0),size:.9,shape:I.Soft,from:e}),this.run.vfx.flash(i.x[e],o,i.z[e],Yi[a],1.2,.12)}
```

**[main] @873595–873656（右端不含）**

```js
flags:Zm.Hostile|Zm.Capped|(i.homing?Zm.Homing:0),from:this.i
```

**[main] @997113–997429（右端不含）**

```js
shot(e,t,n,r,i={}){let a=this.run,o=a.enemies,s=o.typesOf(e)[0],c=Math.cos(t),l=Math.sin(t),u=a.projectiles.fromBody(e,c,l);a.projectiles.fire({x:o.x[e],y:u.y,z:o.z[e],dx:c,dy:u.dy,dz:l,speed:n,life:i.life??4,radius:.6*(i.size??1),dmg:o.dmg[e]*r,type:s,cls:`special`,flags:Zm.Hostile|Zm.Capped|(i.homing?Zm.Homing:0)
```

co-op jp.updateProxy 体碰传同样 cap，却**没有 floor options**；不能从主 update 推定 proxy 也有 .05 floor：

**[main] @337684–337878（右端不含）**

```js
let t=s&bp,n=s&2?Sp(a):t?.25:0;o.hurt(this.dmg[e]*(this.charm[e]>0?.6:1)*a.diff.enemyDamage,this.typesOf(e)[0],e,NaN,NaN,!1,n,e)&&(this.atkAnim[e]=.35,o.shove(-l/p,-u/p,t?9:3+Math.min(4,c*2.5)))
```

### 2.2 hurt 中完整 floor/cap 公式与先后顺序

**[main] @787791–787809（右端不含）**

```js
var ry=e=>e/(e+45)
```

**[main] @808552–808565（右端不含）**

```js
by=.35,xy=.35
```

**[main] @819419–819877（右端不含）**

```js
let f=e;t&&(f*=Math.max(.5,Math.min(1.6,A.effectiveness(t,this.types)))),f*=1-ry(this.stats.armor),ay[this.ability]?.dmgTaken&&(f*=ay[this.ability].dmgTaken),this.ability===`magic-guard`&&n<0&&(f*=.7),this.ability===`multiscale`&&this.hp>=this.maxHp-.5&&(f*=.5);let p=L_(this.ability);if(p?.hurtMod&&(f=Math.max(0,p.hurtMod(u,this,f,n))),l.floor&&(f=Math.max(f,this.maxHp*l.floor*(1-xy*(e>0?1-Math.min(1,f/e):0)))),o>0&&(f=Math.min(f,this.maxHp*o)),f=cp(u,f)
```

**[main] @315024–315035（右端不含）**

```js
np=.4,rp=40
```

**[main] @316253–316418（右端不含）**

```js
function cp(e,t){if(!e.player.buffs.has(`tm-iron`))return t;let n=e.player.pos;return Math.random()<.6&&e.vfx.burst(n.x,n.y+1.1,n.z,15266559,6,5,I.Spark,.3,.3),t*np}
```

令 D=传入 hurt 的原始 e，M=maxHp，F=options.floor，C=第七实参 o。上面原文等价展开为：

```text
f = D
if type: f *= clamp(effectiveness(type,player.types),.5,1.6)
f *= 1 - armor/(armor+45)
if ability.dmgTaken: f *= ability.dmgTaken
if magic-guard and n<0: f *= .7
if multiscale and hp>=M-.5: f *= .5
if hurtMod exists: f = max(0,hurtMod(run,player,f,n))
f0 = f
if F is truthy:
    f = max(f0, M*F*(1-.35*(D>0 ? 1-min(1,f0/D) : 0)))
if C>0: f = min(f,M*C)
f = tm-iron present ? f*.4 : f
# 随后 overheal → shield → HP。
```

floor 不是简单 max(f,M*F)，仍按 f0/D 的减伤比折减；D>0 时最低为名义 floor 的 .65。cap 是 maxHp 比例，不乘 tier；TM-iron 在 cap 后再乘 .4，所以 floor 不是最终 HP 扣量绝对下限。evade 默认为 1，qy 将闪避概率乘 .5；随机发生在上述伤害公式前（§1.3 原文）。

### 2.3 第三个 Ze.strike 接线点 qy（pack 未列）

§1.2 原文：`qy(run,t)={floor:t>=.3?t:t*(Ze.strike[run.tier]??1),evade:.5}`。全 main 的 Ze.strike 共 **3** 处，qy 调用共 **3** 处（Yy.hurt、Nb.strike、ix.strike，原文见 §1.2）。

| 路径 | 名义 floor F | cap C | evade | wound |
|---|---|---|---:|---|
| Boss 体碰 | .05*S | .25（复合 Alpha 时 Sp 优先） | 1 | 无 |
| Capped hostile 弹体 | .02*S | .15 | 1 | 无 |
| Nb/ix strike 默认 n=.08 | .08*S | .34 | .5 | hurt 成功后 |
| Nb/ix strike 显式 n | n>=.3?n:n*S | .34 | .5 | hurt 成功后 |
| Yy.hurt，t>=0 | qy(max(t,.08)).floor | t>=.3?.6:.34 | .5 | hurt 成功后 |
| Yy.hurt，t<0 | 无 | .34 | 1 | 无 |

S=Ze.strike[tier]??1，为 1/1.2/1.4。例：.05→.05/.06/.07；.02→.02/.024/.028；默认 .08→.08/.096/.112。均为进入 §2.2 折算前的名义 floor。qy 的 >=.3 floor 不放大；只有 Yy 根据 >=.3 改 cap=.6，Nb/ix 仍 .34。

### 2.4 与当前 `_boss_strike` 逐条对应判定

当前 scripts 行号基于本单读取树。`scripts/world.gd:7723` 的核心是 `player.take_damage(guardian.out_dmg()*mul)`；shove 只检查 shove_pow>0 且 player.hp>0。`scripts/player.gd:964` take_damage 为：无敌/iframe 门→randf()<evasion→dmgTaken/fullHp→armor→sturdy→扣 HP，无 floor/cap/shield，也无伤势/成功布尔返回链。

| 项目 | 判定与证据 |
|---|---|
| 集中入口 | **能结构对应 Nb.strike**。main ub.strike 委托 B.strike（§1.2）；当前 world @7764 telegraph、@7811 line 均判几何后调 `_boss_strike`。 |
| 原始伤害 | **只能结构对应，不能宣称数值等价**。main 为 E.dmg[index]*mul*diff.enemyDamage（§1.2）；当前为 guardian.out_dmg()*mul，未逐项重审全部上游倍率。 |
| .05/.02 分派 | **不能直接对应 `_boss_strike`**。二者是体碰/弹体（§2.1），cap .25/.15、无 wound、evade=1；Nb.strike 默认 .08/.34/wound/evade=.5。 |
| floor 参数 | **当前缺口**。`_boss_strike` 无 floorFrac 参数，take_damage 无 §2.2 全式，tier 表有 strike 值不等于已接。需要独立 floor 参数，不是 raw damage 乘 S。 |
| cap / evasion | **当前缺口**。take_damage 无 .34 cap，randf()<evasion 没有 qy 的 .5；main 原文见 §1.2/§1.3/§2.2。 |
| wound | **当前缺口**。main strike 依 hurt 成功布尔结果施伤；当前两函数无此链路。全盾挡也应成功，不能只比 HP 差。 |
| shove | **当前仅近似对应**。main 若干调用 `strike(...)&&player.shove(...)`（下段）；当前只看存活，闪避/无敌仍可能 shove。 |
| shot | **应单独接线**。world @7740 `_boss_shot` 的 `_hostiles` 字典仅 dmg 等，无 Capped/floor/cap；main boss shot 带 Hostile|Capped（§2.1），不能套 `_boss_strike` 的 .08/.34/wound。 |
| source/contact | **当前不足以等价**。main Nb.strike n=-1、s=index 保留归因，同时 n<0 触发 magic-guard ×.7、不走 n>=0 接触反伤；当前 take_damage 无独立 n/s。 |

原作成功才 shove 的直接证据：

**[main] @999920–999984（右端不含）**

```js
this.strike(e,this.chargeMul,.12)&&a.shove(this.cdx,this.cdz,11)
```

### 可施工结论

- 三接线点已证：Boss 体碰 `.05*S`，Capped 弹体 `.02*S`，qy `t>=.3?t:t*S`，S=Ze.strike[tier]??1；不要全局乘 boss raw damage。
- 完整 floor/cap 照抄 §2.2：保留 xy=.35、类型/armor/ability/hurtMod 先后、cap 后 TM-iron ×.4、吸收顺序。
- `_boss_strike` 可对接 Nb.strike：默认 F=.08*S、C=.34、evade=.5，成功 wound；保留显式 n。Yy 的 >=.3 cap=.6 不得扩给 Nb/ix。
- .05/.02 分接体碰/弹体，proxy 体碰原文缺 floor，不可无证据自动补成主路径。

## 3. alpha 基础概率：前提纠正，director 使用时间表 — 全证

### 3.1 alphaCap1 实为 Alpha 命中伤害 cap

**[main] @322213–322272（右端不含）**

```js
Sp=e=>e.stage===1&&!e.endless?Ze.alphaCap1[e.tier]??.25:.25
```

**[main] @819834–819867（右端不含）**

```js
o>0&&(f=Math.min(f,this.maxHp*o))
```

全 main 的 Sp 调用仅 @336400 主体碰、@337701 proxy 体碰、@499028 hostile Alpha 弹体（完整原文见 §2.1），均传 player.hurt 的 **第七实参 o**，没有进入 director 或 rng.chance。

完整公式：

```text
C_alpha = (stage==1 && !endless) ? (Ze.alphaCap1[tier]??.25) : .25
f_after_cap = min(f_after_floor,maxHp*C_alpha)
```

stage1 普通/困难/噩梦上限为 maxHp 的 .15/.25/.25，其他情境 .25；Capped flag 优先时用 .15，不读 Sp。故 pack §1.1 和任务背景中“stage1 alpha chance 上限”被原文反证，**应更正为 Alpha 命中伤害上限**。本文件补证，不回写已关账文件。

### 3.2 director alpha 完整调度与随机源

**[main] @851405–852072（右端不含）**

```js
constructor(e){this.run=e,this.rng=new Tu(e.seed^859847),this.buildPool();let t=this.rng;for(let e=0;e<3;e++)this.addCard();if(this.credits=0,e.endless){this.beats=[{kind:`card`,next:60,every:[48,72]},{kind:`alpha`,next:150,every:[150,150]},{kind:`horde`,next:235,every:[140,160]},{kind:`totem`,next:290,every:[200,220]},{kind:`elitewave`,next:330,every:[180,180]},{kind:`summoner`,next:380,every:[340,380]},{kind:`event`,next:t.range(170,230),every:[220,260]}];return}let n=[];for(let e=1;e<9.6;e+=t.range(.8,1.2))n.push({t:e*60,kind:`card`});n.push({t:150,kind:`alpha`},{t:330,kind:`alpha`},{t:480,kind:`alpha`}),e.boosts.has(`honey`)&&n.push({t:240,kind:`alpha`});
```

**[main] @852468–852653（右端不含）**

```js
let i=Ze.early[e.tier]??0;if(i)for(let e of n)e.kind!==`card`&&e.kind!==`event`&&(e.t=Math.max(60,e.t-i));e.tier>=2&&n.push({t:510,kind:`totem`}),n.sort((e,t)=>e.t-t.t),this.timeline=n}
```

**[main] @857255–857413（右端不含）**

```js
update(t){let n=this.run;if(n.endless){this.updateEndless(t);return}let r=n.stageTime;for(let e of this.timeline)e.done||r<e.t||(e.done=!0,this.fire(e.kind));
```

**[main] @858705–858771（右端不含）**

```js
fire(e){let t=this.run;if(e===`card`||this.cards.length)switch(e){
```

**[main] @859004–859445（右端不含）**

```js
case`alpha`:{let e=this.rng.pick(this.cards),n=this.spawnPoint(20,28);if(!n)return;let r=e.id,i=A.evolutionsOf(r);i.length&&t.stage>=1&&(r=this.rng.pick(i).id),A.hasSprite(r)||(r=e.id),t.sprites.get(r),t.enemies.spawn(r,n.x,n.z,this.hpMult(),this.dmgMult(),R.Alpha),t.ui.banner(c(`¡Pokémon Alfa!`),c(`Un {name} gigante y furioso ha aparecido`,{name:A.get(r).name}),`#ff5a4a`,{species:r}),t.audio.alarm(),t.cry(r),t.hints.show(`alpha`);break}
```

普通 director（包括 stage1）全式：

```text
baseTimes = [150,330,480]                  # 每区 stageTime
if boosts.has("honey"): baseTimes += [240]
early = Ze.early[tier] ?? 0
alphaTimes = sort(baseTimes.map(t => early ? max(60,t-early) : t))
每个未 done 事件：stageTime>=t 时先 done=true，再 fire("alpha")。
fire 需 cards 非空；rng.pick(cards)，spawnPoint(20,28) 失败则 return；
若有进化且 stage>=1，rng.pick(evolutions)，无 sprite 回退原卡；
enemies.spawn(...,R.Alpha)。没有 alpha chance roll。
```

cap **不在生成公式里**。不能伪造 `min(baseChance,alphaCap1)`，也不能写基础概率为 0；该路径没有这个变量。done 先于生成，cards 为空、无合法点、spawn 容量失败可使本次不出实体；“没有概率门”不等于“绝对必出”。

随机源是 director 独立 Tu(seed^859847)，随机的是卡片/进化/落点，非本次是否按概率生成；不是全局 F 或 Math.random：

**[main] @146082–146431（右端不含）**

```js
Tu=class{s;constructor(e){this.s=e>>>0||2654435769}next(){let e=this.s=this.s+1831565813>>>0;return e=Math.imul(e^e>>>15,e|1),e^=e+Math.imul(e^e>>>7,e|61),((e^e>>>14)>>>0)/4294967296}range(e,t){return e+(t-e)*this.next()}int(e,t){return Math.floor(this.range(e,t+1))}pick(e){return e[Math.floor(this.next()*e.length)]}chance(e){return this.next()<e}
```

**[main] @855858–856254（右端不含）**

```js
spawnPoint(t=24,n=36){let r=this.run.player.pos,i=this.run.terrain.play-6;for(let a=0;a<16;a++){let a=this.rng.range(0,Math.PI*2),o=this.rng.range(t,n),s=r.x+Math.cos(a)*o,c=r.z+Math.sin(a)*o;if(!(!this.run.terrain.inBounds(s,c,6)&&(s=Nc(s,-i+.5,i-.5),c=Nc(c,-i+.5,i-.5),Math.hypot(s-r.x,c-r.z)<e.RIM_MIN))&&(!this.run.terrain.inWater(s,c)||this.run.terrain.hasWater))return{x:s,z:c}}return null}
```

**[main] @325053–325563（右端不含）**

```js
spawn(e,t,n,r,i,a=0,o=1){if(a&1536){let e=this.run;if(this.mass>=e.maxEnemies+200)return-1;if(e.coop){if(this.count>=e.enemyCap+200)return-1}else if(this.count>=e.enemyCap){if(this.hordeCarry+=o,this.hordeCarry<(e.director?.hordeWeight??2))return-1;if(o=this.hordeCarry,this.hordeCarry=0,this.count>=e.enemyCap+yp)return this.isAlive(this.lastHorde)&&this.flags[this.lastHorde]&1536&&this.addWeight(this.lastHorde,o),-1}}let s;if(this.free.length)s=this.free.pop();else if(this.n<2200)s=this.n++;else return-1;
```

spawnPoint 最多尝试 16 次，抽 angle∈[0,2π)、radius∈[20,28)，检查边界/水域，失败返回 null。Alpha 使用通用槽位分配：有 free 槽复用，否则 n<2200 才新建，池满返回 -1。前段 maxEnemies/enemyCap 门仅在 flags&1536（Swarm|Stampede）成立时执行，不是 Alpha 的数量 cap；这些均不是 alphaCap1 控制的 chance。

普通 spawnCard 中存在概率，但产出的是 Elite：

**[main] @856751–857255（右端不含）**

```js
spawnCard(e,t=0,n=1){let r=this.spawnPoint();if(!r)return;let i=this.run.stage===1&&this.run.stageTime<90,a=this.run.endless,o=a?Math.min(.25,.012+this.run.time/60*.004)*a.curse.elite:.012+this.run.stageTime/60*.004+(this.run.stage-1)*.03,s=!i&&this.rng.chance((o+(Ze.elite[this.run.tier]??0)+(this.run.player.stats.difficulty-1)*.05+(this.run.events?.eliteBonus??0))*this.run.player.stats.eliteSpawn)?R.Elite:0;this.run.enemies.spawn(e.id,r.x,r.z,this.hpMult(),this.dmgMult(),t|s,n),this.spawnedTotal++}
```

stage1 前 90 秒禁 elite；常规式 `rng.chance((.012+stageTime/60*.004+(stage-1)*.03+(Ze.elite[tier]??0)+(difficulty-1)*.05+(events?.eliteBonus??0))*eliteSpawn)` 产出 R.Elite。完整 endless 分支以上述原文为准。这里没有 alphaCap1/R.Alpha，不能用 elite 概率填 alpha。

### 3.3 与当前 ALPHA_TIMES 的关系

当前 scripts/world.gd @65：ALPHA_TIMES=[150,330,480]；@12330–12332 依 `elapsed>=tier_timeline_time(ALPHA_TIMES[_alpha_idx])` 调 `_spawn_alpha()`，这三次的时间和 early 提前与 bundle 对应。honey @10292/@14966 将 `_honey_at` 设为 240，@12419 直接判 `elapsed>=_honey_at`，**没有经过 tier_timeline_time**：基础 240 秒对应，但 tier1/2 的 honey 提前 15/30 秒尚未接。这是时间表接线差异，**不是 alphaCap1 生成概率缺失**。

原作普通 director 是 **alpha 时间表 + 随机选种/落点**；并存的概率刷怪属于 Elite，不能表述为 alpha 概率与时间表并存。当前 `_spawn_alpha` @5871 从 `ZONES[zone-1]["pool"]` 随机选 base_sp，再取单个 evo_target（且需 ModelRig 支持）；原作从 cards 选卡后随机取 evolutions/回退。两边源池/进化选择及落点范围均有差别（当前 _ring_pos(24,36)，原作 spawnPoint(20,28)），不能把整个生成算法判作等价。

endless 是另一套循环 beat，初始 next=150，后续间隔取 curse.alphaEvery，依然时间驱动，未读 alphaCap1：

**[main] @857975–858167（右端不含）**

```js
updateEndless(t){let n=this.run,r=n.endless,i=n.time;for(let e of this.beats)i<e.next||(e.next=i+(e.kind===`alpha`?r.curse.alphaEvery:this.rng.range(e.every[0],e.every[1])),this.fire(e.kind));
```

### 可施工结论

- alphaCap1 接 Alpha **命中伤害 cap**，全式见 §3.1；消费者为主/proxy 体碰与非 Capped 的 Alpha hostile 弹体。
- 普通 alpha 调度全式 `sort(([150,330,480]+(honey?[240]:[])).map(t=>early?max(60,t-early):t))`，early=Ze.early[tier]??0；当前固定 ALPHA_TIMES 有原文依据。
- 随机源 Tu(seed^859847)，随机选卡/进化/落点；保留 cards/落点/容量失败语义，无需发明生成概率公式。
- alphaCap1 真正未接的是 Alpha 命中伤害上限；另有 honey 240 秒事件未减 early 的已证差异。不要增加虚构的 alpha 概率生成。

## 4. 仍 UNPROVEN 清单与证据强度

| 项目 | 状态与边界 |
|---|---|
| “stage1 alpha 基础生成概率，与 alphaCap1 取 min” | **未证且前提被反证**：Sp 全部调用为 hurt cap，director alpha 时间事件无此概率门；不是待补的一个概率常量。 |
| 任意直接赋 HP 的恢复都受 wound .5 | **UNPROVEN**：只证 heal 及经 heal 的调用链，不推及直接赋 hp。 |
| 当前 `_boss_strike` 全部逐招 mul/n、out_dmg 上游倍率与原作等价 | **UNPROVEN**：本单证集中入口、floor/cap 和当前缺口，没有逐招复审全部 C21/C22 机制。 |
| 跨版本/服务端其他 alpha 概率机制 | **UNPROVEN**：结论限所列哈希的 main/news 客户端，不推定其他版本或服务端。 |
| 动态运行表现 | **未验证**：本单为静态控制流/原文核验，未跑原作或移植游戏。 |

三目标强度：**wound 全证；strike 全证（集中管线与端口对应已定位，逐招等价不含在内）；alpha 全证，以原文反证纠正生成概率前提并证得时间表。**

复核方法：全文枚举 woundT、.wound(、Gy(、Ze.strike、qy(、alphaCap1、Sp(，并检查 director 的 R.Alpha 生成点；所有 JS 块逐字核对为镜像连续子串。未修改或复制原料进项目。


交付核验：50/50 个 JS 证据块与所标镜像偏移逐字一致；三节均含可施工清单。原有 scripts/design 的 23 个文件内容聚合 SHA-256 在本单前后均为 `c9905b81b44fc340120b1a36532d4e8e89ac4922f9400848c3f7b9b9ce6c7e96`，未写入这些既有文件。镜像 SHA-256 复核与页首一致。未运行游戏或新增测试。
