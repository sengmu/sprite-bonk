# SpriteBonk 美术补齐清单 v3

- 来源：sengmu/sprite-bonk main f49c1dc。主源是 `src/` 下的 world.gd、ui_icon.gd、wallet.gd、touch_controls.gd（行号以它们为准）。
- 补充来源：本机另一份 f49c1dc 拷贝（world.gd 与 src 逐字节相同），从中只读了 game_data.gd（RARITY_NAMES 68、VITAMINS 26）、profile.gd（SHOP_ITEMS 471、挑战文案 _desc_for 237）、ui_theme.gd（RARITY 色 35、TYPE_COLORS 58）、items.json（126 件物品）、project.godot（config/icon）。这份拷贝不是 git 仓库，文件头带有工具包裹标记，属于“待以仓库原件复核”的二手证据。
- 全部是参考稿提示词，不改仓库、不出图、不进商店。

## (a) 尚无效果图的界面 / 浮层

已有效果图：U1 战斗 HUD（_build_hud 2774）、U2 主菜单（_build_menu 3684）、U3 升级三选一（_build_draft 4905）、U4 实验室（_build_lab_panel 4114）、U5 结算（_build_result 5476）、U6 钱包（_build_wallet_panel 3979）。

| 提示词 | 界面 | 代码函数（行号） | 代码里的实际中文（节选） | 效果图里的改动 |
|---|---|---|---|---|
| S07_loadout | 出战配置 | _build_loadout 16420；_open_loadout 16523；_loadout_fill_detail 16568；_loadout_fill_team 16752；_loadout_fill_grid 16791；_loadout_fill_bag 16852 | 队伍（点队友可换为出战） 16461/16789；返回 16497；开始 / 开始 · %s 16507/16566；图鉴 · 稀有 16593；体力/攻击/防御/特攻/特防/速度 16597；特性：16647；初始招式 16649；相性 16658；弱点/抗性/免疫 16673-16677；进化链 16695；大招 16708；解锁条件（联盟挑战） 16718；锁 · 16807；背包带入 %d/%d（开局时消耗 · 研究室可扩到 3） 16856；档案预设 16542 | 格子不写物种名（代码里是宝可梦名）；开始按钮只写“开始”；背包物品用中性名（成长星糖、福运蛋） |
| S08_pause | 暂停 · 状态 | _build_pause 15534；_open_pause 15918；_pause_fill_status 15715 | 暂停 15550；状态/图例/设置 15557；全部设置 15615；继续 15626；回主菜单 15631；再点一次回主菜单（3 秒） 15665；战力 15723；招式 15733；%s %d级 15743；威力 %d · 物理/特殊 15747；大招：%s（充能 %.0f%%） 15751；维生素 15754；物品 15768；队伍 15782；本局 15803；精灵：/区域：/难度：普通/用时：/星尘：/金币：/击杀：/咆哮 ×%d 15810-15820；副标题 “%s · 第 %d 区 · %s” 15925 | 区域名“常磐森林”改为“翠叶森林”；维生素“HP 增强剂”改为“体力补剂” |
| S09_settings | 设置 · 声音 | _build_sound_panel 4535；_open_settings 4592；_settings_show_tab 4604；_settings_page_sound 4684 | 设置 4552；声音/图形/控制/键位/界面/账户 4553（触屏时“键位”显示为“操作” _touch_text_sync 5907）；关闭 4562；主音量/音乐/音效/叫声 4686；后台静音 4689 | 无 |
| S10_stardust_shop | 星尘商店 | _build_shop_panel 4416；_refresh_shop 4463；_refresh_shop_countdown 4457 | 星尘商店 4431；背包道具，供接下来的对局使用。…名额在 00:00 UTC 刷新。 4437；今日名额刷新倒计时：%d 小时 %d 分（00:00 UTC） 4461；✦ 星尘 %d（累计 %d） 4470；背包 %d/%d · 今日 %d/%d 4490；下一份 ✦ %d 4492；今日最后一份 4494；今日售罄 4500；背包已满 4503；✦ %d（星尘不足） 4506；购买 ✦ %d 4509；关闭 4450；商品名/描述来自 profile.gd SHOP_ITEMS 471 | 商品名用中性名；行首加了物品小图标（代码里目前没有，属建议新增）；说明长句 4437 为控字数没画 |
| S11_league_challenge | 联盟挑战 · 终身挑战 | _build_unlock_panel 4834；_refresh_unlock_panel 4875 | 联盟挑战 · 终身挑战 4849；联盟 %d 只 · 累计击杀 %d · 完成对局 %d · 阿尔法 %d · 守护者 %d · 收服 %d 4880；已加入联盟 ★ / 挑战完成 · 等待遭遇 ✓ / 进行中 4890；“%s（%s）· %s” 4891；“　%s：%d / %d” 4899；（系统未实装） 4901；关闭 4860；条件文案 profile.gd _desc_for 237-267 | 物种名换成中性示例名（苔团、砾壳、焰尾），等文案替换表 |
| S12_inrun_shop | 局内商店（代码叫“喵喵商店”） | _open_shop 7434；_shop_refresh 7456；_build_shop 7571 | 喵喵：「有钱吗，喵？」 7459/7461；%d 金币 7462；「你什么都有了，喵。…」 7468；买得太多又不打开精灵球，喵喵下次会涨价。 7599；卡片 “名\n效果\n【稀有度】持有 n/m\n价格/已售出” 7480；更新库存 · %d 金币 7506；出售 %s +%d / 确认出售 %s +%d 7518；出售你的物品： 7629；离开 7607 | 标题改为“商店”；提示改为“买得太多又不开宝箱，商人下次会涨价。”；店主改为原创背包小商人（不画猫）；卡片加了物品图标（建议新增） |
| S13_chest_pick | 宝箱 · 选择一件带走 | _build_choice 7648；_choice_show 7689；_roll_chest_item 7291（多选 7350） | 宝箱 / 选择一件带走 / 全部出售 +%d 金币 7350；单件版 获得物品 / 选择带走，或出售换金币 / 出售 +%d 金币 7307、7365；卡片文字 _item_card_text 7282 | 物品名用中性名，卡片加图标（建议新增） |
| S14_blessing | 祭坛 · 祝福 | _build_blessing 10130；offer_blessing 10166；_render_blessing 10184 | 标题 “%s · 祝福” 10176（祭坛名 ALTAR_NAMES 48：未知祭坛/稀有未知祭坛/史诗未知祭坛/黄金未知祭坛/彗星祭坛）；选择一项祝福（本祭坛还可选 %d 次） 10185；稀有度片 GameData.RARITY_NAMES 10219；祝福文案 BLESSING_DEFS 54-67；查看我的队伍 [Tab] 10157（触屏去掉 [Tab]） | “未知祭坛”改为“古石祭坛” |
| S15_bigmap | 大地图 | _build_bigmap 15957；open_big_map 16009；_bigmap_refresh_list 16045；绘制在 big_map.gd _draw 35 | 大地图 15989；点击地图放置标记（最多 3 个）；点已有标记可删除。 15990；已探索 %d%% 16053；祭坛/宝箱/标记 · %d 16055；守护者 · 存活 16061；闪光遭遇 · 出现中 16063；关闭 15994 | 无 |
| S16_team_view | 查看我的队伍（从升级/祝福偷看暂停状态页） | _open_team_view 15903；按钮 4962（升级）、10157（祝福） | 同暂停状态页；打开时隐藏升级/祝福面板 15908/15910；继续后回到原弹窗 15939-15948 | 同 S08；物品用中性名，队友用示例名 |
| S17_objective_drawer | 战斗中目标抽屉 | _build_objective 14106；_p3_refresh_objective 14194；_p3_fill_drawer 14306；_obj_open_drawer 14417；_event_list 16259 | 目标 · %d 项 14328；联盟挑战 14205/14350；查看全部挑战 14182；事件行 16264-16304：雷暴/幽灵迷雾/日蚀/黄金喵喵（EVENT_DEFS 9013）、剩余 %ds、彗星祭坛、剩余 %ds · 充能 %d%%、联盟遭遇、闪光遭遇、%s · 逃走 %ds、虫群/虫群来袭中、喵喵在拜访/本区有喵喵商店、阿尔法/阿尔法出没；目标卡 “%s · 还差 %d” / “%s · 条件 %d/%d” 16225-16236 | 物种名用示例名；不画“喵喵”行 |
| S18_pause_legend | 暂停 · 图例 | _pause_fill_legend 15861 | 地图图例 15862；守护者/阿尔法/可收服目标/宝藏/祭坛 / 图腾/队友/玩家标记（大地图） 15864-15867；稀有度 15877；普通/稀有/史诗/传说 15882 | 无（但只有 4 档稀有度，见待定项） |
| S19_pause_quick | 暂停 · 设置（快捷） | _pause_fill_quick 15689 | 镜头辅助（瞄准） 15696；固定摇杆 15700；大招自动释放 15704；触控按钮大小 15705；全部设置 15615 | 无 |
| S20_settings_controls | 设置 · 控制 | _settings_page_controls 4711（另有 图形 4692、操作/键位 4732、界面 4753、账户 4769、法律 4801 页，未单独出图） | 控制 4712；大招自动释放 4713；大招演出姿势 4714；镜头辅助（瞄准） 4715；固定摇杆 4719；触控按钮大小 4723；镜头距离 4727；镜头灵敏度 4729；镜头 Y 轴反转 4730 | 无 |
| S21_recompile_terminal | 重编译终端（代码叫“多边兽”） | _porygon_open 9894；_porygon_mod_text 9859；PORYGON_BY 9841 | 多边兽 · 重编译 / 选择一组重编译（本局生效） / 离开（不选择） 9905；卡片 “重编译\n%s\n代价：%s” 9903；交互提示 多边兽终端 · 按 E 重编译：三选一（增益＋代价） 9511；重编译完成：%s / %s 9918 | 标题改为“数据终端 · 重编译” |
| S22_mimic_copy | 复制物品（代码叫“百变怪”） | _open_ditto 9635 | 百变怪：复制哪件物品？ / 现在不要 9654；选择一件物品，百变怪会变成它 9651；（已满：%s） 9653；【已满】 9648；百变怪变成了%s！ 9665；这件物品已持有上限 9659 | 改为“拟态团”，原创淡紫果冻小团 |
| S23_battle_overlays | 战斗中临时浮层（交互气泡、横幅、大招切入、飘字） | 交互气泡 _p4_layout_bubble 14721 / _layout_prompt 14795；文字 _prop_label_kbd 9473 起（9471 把“按 E”换成 _ik()）；横幅 show_banner 5865；大招切入 2814-2830 / show_ult_cutin 11493；飘字 spawn_floater 11072 | 免费宝箱 · 按 E 开启 9497（触屏显示“点互动”5916）；必杀技！ 2828；大招名 ult.gd NAMES_ZH；天气变化：%s！ 10727；冰碎！ 7756（ice_shatter） | 无 |
| S24_ally_choice | 闪光队友替换 | _offer_shiny_ally 16942 | 闪光队友 / 只能带一只闪光队友；替换后旧队友回到森林 / 留下新队友 / 放生新队友 16951 | 无（“闪光”这个机制有联想风险，见下） |

其他没单独出图的界面（结构跟上面某张相同，或者只有文字）：
- 获得物品单卡弹窗 7307/7365：S13 去掉两张卡就是它。
- 设置的 图形 4692、操作/键位 4732、界面 4753、账户 4769（钱包面板、重置存档两步确认 4782-4792、隐私政策与服务条款 4797）、法律页 4801：版式跟 S09/S20 相同。
- 经典布局的 HUD 目标卡 _refresh_goal_card 16200 和事件胶囊 _refresh_event_pills 16322：手机新布局已经不常驻（16218），所以不出图。
- 老虎机结果横幅 9777-9809、各交互道具提示 9477-9517、咆哮神龛 10072-10075：都是纯文字横幅或气泡，样式就是 S23。
- 加载：没有独立的加载页，只有横幅“正在开辟下一区域…”（10429）。project.godot 没设 boot splash，所以启动时会显示 Godot 默认画面。A18 是一张不带 logo 的启动图参考，放不放由你定。

## (b) 不需要建模的 2D 美术素材

需要建模、不做的：所有生物（model_rig.gd，55 个物种标签）、头像（ui_theme.gd portrait 410 行，从模型烘焙）、场景道具、地形贴图（world.gd 1295-1298 res://assets/textures）、祭坛和宝箱的 3D 实体。

### b1. UiIcon 程序绘制图标（ui_icon.gd）：44 个名字 + 1 个兜底图形

| 名字 | ui_icon.gd 行 | 表格位置 | 备注 |
|---|---|---|---|
| sword | 63 | A01 #1 |  |
| wind | 67 | A01 #2 |  |
| heart | 73 | A01 #3 |  |
| speed | 77 | A01 #4 |  |
| crit | 84 | A01 #5 |  |
| area | 91 | A01 #6 |  |
| up | 95 | A01 #7 |  |
| plus | 97 | A01 #8 |  |
| shield | 100 | A01 #9 |  |
| luck | 102 | A01 #10 |  |
| hourglass | 108 | A01 #11 |  |
| spark | 110 | A01 #12 | 星尘 3005 |
| coin | 112 | A03 #1（+全彩 #7） | 代码是双圈金币 3012 |
| ball | 115 | A03 #4 改为钱包图形（不画球） | 代码在钱包菜单项 3805 和宝箱价格 3019 用了这个图形。红白球有联想风险，钱包改成钱包图形，宝箱价格改用 chest |
| skull | 121 | A01 #13 |  |
| reroll | 126 | A01 #14 |  |
| skip | 131 | A01 #15 |  |
| banish | 135 | A01 #16 |  |
| close | 138 | A01 #17 |  |
| check | 141 | A01 #18 |  |
| flask | 143 | A01 #19 |  |
| bag | 146 | A01 #20 |  |
| shake | 156 | A02 #1 |  |
| blessing | 165 | A02 #2 |  |
| lock | 172 | A02 #3 |  |
| sound | 176 | A02 #4 |  |
| trophy | 180 | A02 #5 |  |
| sun | 184 | A02 #6 |  |
| rain | 189 | A02 #7 |  |
| snow | 196 | A02 #8 |  |
| fog | 201 | A02 #9 |  |
| flame | 205 | A02 #10 |  |
| drop | 207 | A02 #11 |  |
| leaf | 210 | A02 #12 |  |
| bolt | 213 | A02 #13 |  |
| candy | 215 | A02 #14 |  |
| chest | 219 | A03 #3 |  |
| egg | 223 | A02 #15 |  |
| play | 226 | A02 #16 |  |
| pause | 228 | A02 #17 |  |
| target | 231 | A02 #18 |  |
| exclaim | 235 | A02 #19 |  |
| expand | 240 | A02 #20 |  |
| pin | 246 | A03 #5 |  |
| _（兜底：圆环加圆点） | 251 | A03 #6 | |

这些图标的使用位置：HUD 2868/2965/3005/3012/3019/3126/3144/3288/3301/3318，主菜单 3805-3855，升级界面 4945-4951，祝福 10213，类型 2746，维生素 P4_VIT_ICON 14511，背包 LS_ITEM_ICONS 16848，触控 touch_controls.gd 104-114。

### b2. 货币、宝箱（A03）
- 金币：双圈 #ffd23a（world.gd 3012，ui_icon.gd coin）。星尘：✦（3005，文案 4470）。
- 宝箱：免费宝箱 9497，诅咒宝箱 9499，付费宝箱（代码叫“精灵球”）9494/9495，咆哮奖励宝箱（代码叫“超级球箱”）10074/10094。A03 第 11-16 格画免费、诅咒、付费三种，各有开和关两种状态。咆哮奖励宝箱建议直接沿用付费宝箱的图，本轮没单独画。

### b3. 触控按钮（A04，touch_controls.gd）
- 互动 exclaim 104，跳跃 up 106，冲刺 wind 108，锁定 crit 110，瞄准 target 112，暂停 pause 114，大招“必”131，摇杆 9-12/68-69。

### b4. 类型 / 招式类别（A05）
- TYPE_HUD 157-167 有 18 种类型（普通 火 水 草 电 冰 格斗 毒 地面 飞行 超能 虫 岩石 幽灵 龙 恶 钢 妖精），颜色取 ui_theme.gd TYPE_COLORS 58。代码 _type_icon 2746 只给火、水、草、电配了图标，其余都用 spark。A05 是 18 枚类型徽章，另加“物理/特殊”两枚类别徽章（15747、16653）。

### b5. 天气 / 状态（A06）
- 天气 WEATHER_TABLE 10673：晴、雨、烈日、沙暴、冰雹、雾、灰烬雨。代码 _refresh_weather_chip 12166 现在只复用 sun/rain/wind/snow/fog 五个图标。
- 状态 SCN 12004：灼伤、中毒、麻痹、睡眠、冰冻、混乱、魅惑、缠绕，另有湿润 12008。

### b6. 稀有度卡框（A07）
- GameData.RARITY_NAMES（game_data.gd 68）：普通、优秀、稀有、史诗、传说。颜色取 ui_theme.gd RARITY 35：#547cd6、#39c6d8、#36c96a、#9a6aff、#ffd23a。用在祝福 10194、升级 5155、商店和宝箱卡 7478/7700。

### b7. 维生素（A08）
- game_data.gd VITAMINS 26-38 共 11 种，图标映射见 world.gd P4_VIT_ICON 14511。代码里的名字是宝可梦道具名（蛋白质 Protein、钙片 Calcium、HP 增强剂、要害镜 Dire Hit、超级伤药、星星碎片等），而且带英文。建议改名：

| id | 代码名 | 建议名 |
|---|---|---|
| protein | 蛋白质 Protein | 攻击补剂 |
| calcium | 钙片 Calcium | 法力补剂 |
| iron | 钢铁 Iron | 护甲补剂 |
| carbos | 速度剂 Carbos | 迅捷补剂 |
| hp-up | HP 增强剂 | 体力补剂 |
| ether | 以太 Ether | 攻速补剂 |
| dire-hit | 要害镜 Dire Hit | 会心镜 |
| exp-candy | 经验糖 Exp Candy | 经验糖 |
| nugget | 金珠 Nugget | 金砂 |
| super-potion | 超级伤药 | 再生药 |
| star-piece | 星星碎片 | 幸运星砂 |

### b8. 持有物品（A09-A16，共 126 件）
- 来源是 items.json，读取入口为 GameData.item_def / item_keys，显示在 world.gd _item_label 7259、_item_card_text 7282、实验室档案 4328、暂停物品 15778、商店 7480。
- 现状：代码里物品只显示文字，没有图标（只有背包的 6 件借用了 UiIcon 图形，16848）。`name` 字段是西班牙语（如 Carbón、Master Ball），游戏内会直接显示出来，所以全部 126 件都是宝可梦道具，都要改名。下表的“建议名”只是美术侧的中性名建议，最终以叙事文案为准。

| # | id | 稀有度 | 代码名（西语） | 建议中性名 | 表格位置 |
|---|---|---|---|---|---|
| 1 | charcoal | 普通 | Carbón | 余烬炭块 | A09_items_1 #1 |
| 2 | mystic-water | 普通 | Agua Mística | 清泉滴瓶 | A09_items_1 #2 |
| 3 | miracle-seed | 普通 | Semilla Milagro | 新芽种子 | A09_items_1 #3 |
| 4 | magnet | 普通 | Imán | 磁石块 | A09_items_1 #4 |
| 5 | never-melt-ice | 普通 | Hielo Perpetuo | 恒冰晶 | A09_items_1 #5 |
| 6 | black-belt | 普通 | Cinturón Negro | 武者腰带 | A09_items_1 #6 |
| 7 | poison-barb | 普通 | Flecha Venenosa | 紫刺针 | A09_items_1 #7 |
| 8 | soft-sand | 普通 | Arena Fina | 细沙袋 | A09_items_1 #8 |
| 9 | sharp-beak | 普通 | Pico Afilado | 锐羽喙 | A09_items_1 #9 |
| 10 | twisted-spoon | 普通 | Cuchara Torcida | 弯折银勺 | A09_items_1 #10 |
| 11 | silver-powder | 普通 | Polvo Plata | 银鳞粉 | A09_items_1 #11 |
| 12 | hard-stone | 普通 | Piedra Dura | 坚岩石 | A09_items_1 #12 |
| 13 | spell-tag | 普通 | Hechizo | 幽纸符 | A09_items_1 #13 |
| 14 | dragon-fang | 普通 | Colmillo de Dragón | 龙牙 | A09_items_1 #14 |
| 15 | black-glasses | 普通 | Gafas de Sol | 墨镜 | A09_items_1 #15 |
| 16 | metal-coat | 普通 | Revest. Metálico | 钢甲片 | A09_items_1 #16 |
| 17 | silk-scarf | 普通 | Pañuelo de Seda | 丝绸围巾 | A10_items_2 #1 |
| 18 | fairy-feather | 普通 | Pluma Feérica | 粉羽毛 | A10_items_2 #2 |
| 19 | oran-berry | 普通 | Baya Aranja | 蓝浆果 | A10_items_2 #3 |
| 20 | quick-powder | 普通 | Polvo Veloz | 迅捷粉 | A10_items_2 #4 |
| 21 | bright-powder | 普通 | Polvo Brillo | 闪光粉 | A10_items_2 #5 |
| 22 | amulet-coin | 普通 | Moneda Amuleto（星尘商店中文名：护符金币） | 招财护符 | A10_items_2 #6 |
| 23 | scope-lens | 普通 | Periscopio | 瞄准镜片 | A10_items_2 #7 |
| 24 | wide-lens | 普通 | Lupa | 广角镜 | A10_items_2 #8 |
| 25 | zoom-lens | 普通 | Telescopio | 望远筒 | A10_items_2 #9 |
| 26 | soothe-bell | 普通 | Cascabel Alivio | 安宁铃 | A10_items_2 #10 |
| 27 | lax-incense | 普通 | Incienso Suave | 安神香 | A10_items_2 #11 |
| 28 | honey | 普通 | Miel（星尘商店中文名：甜甜蜜） | 蜂蜜罐 | A10_items_2 #12 |
| 29 | cleanse-tag | 普通 | Amuleto | 净化符 | A10_items_2 #13 |
| 30 | potion | 普通 | Poción | 回复药水 | A10_items_2 #14 |
| 31 | lucky-punch | 普通 | Puño Suerte | 幸运拳套 | A10_items_2 #15 |
| 32 | big-nugget | 普通 | Maxipepita | 大金块 | A10_items_2 #16 |
| 33 | grip-claw | 普通 | Garra Garfio | 抓钩 | A11_items_3 #1 |
| 34 | berry-juice | 普通 | Zumo de Baya | 果汁杯 | A11_items_3 #2 |
| 35 | soda-pop | 普通 | Refresco | 汽水瓶 | A11_items_3 #3 |
| 36 | muscle-band | 优秀 | Cinta Fuerte | 力量护腕 | A11_items_3 #4 |
| 37 | wise-glasses | 优秀 | Gafas Especiales | 智者眼镜 | A11_items_3 #5 |
| 38 | quick-claw | 优秀 | Garra Rápida | 疾爪 | A11_items_3 #6 |
| 39 | razor-claw | 优秀 | Garra Afilada | 利爪 | A11_items_3 #7 |
| 40 | shell-bell | 优秀 | Cascabel Concha | 贝壳风铃 | A11_items_3 #8 |
| 41 | leftovers | 优秀 | Restos | 剩饭便当 | A11_items_3 #9 |
| 42 | rocky-helmet | 优秀 | Casco Dentado | 岩刺头盔 | A11_items_3 #10 |
| 43 | light-clay | 优秀 | Refleluz | 光黏土 | A11_items_3 #11 |
| 44 | air-balloon | 优秀 | Globo Helio | 气球 | A11_items_3 #12 |
| 45 | white-herb | 优秀 | Hierba Blanca | 白草 | A11_items_3 #13 |
| 46 | power-herb | 优秀 | Hierba Única | 力量草 | A11_items_3 #14 |
| 47 | sitrus-berry | 优秀 | Baya Zidra | 金柑果 | A11_items_3 #15 |
| 48 | lucky-egg | 优秀 | Huevo Suerte（星尘商店中文名：幸运蛋） | 福运蛋 | A11_items_3 #16 |
| 49 | big-root | 优秀 | Raíz Grande | 粗树根 | A12_items_4 #1 |
| 50 | smoke-ball | 优秀 | Bola de Humo | 烟雾弹 | A12_items_4 #2 |
| 51 | metronome | 优秀 | Metrónomo | 节拍器 | A12_items_4 #3 |
| 52 | flame-orb | 优秀 | Llamasfera | 火焰珠 | A12_items_4 #4 |
| 53 | toxic-orb | 优秀 | Toxisfera | 毒雾珠 | A12_items_4 #5 |
| 54 | snowball | 优秀 | Bola de Nieve | 雪球 | A12_items_4 #6 |
| 55 | binding-band | 优秀 | Banda Atadura | 束缚带 | A12_items_4 #7 |
| 56 | smooth-rock | 优秀 | Roca Suave | 光滑石 | A12_items_4 #8 |
| 57 | white-flute | 优秀 | Flauta Blanca | 白笛 | A12_items_4 #9 |
| 58 | adrenaline-orb | 优秀 | Nerviosfera | 激昂珠 | A12_items_4 #10 |
| 59 | repel | 优秀 | Repelente | 驱散香囊 | A12_items_4 #11 |
| 60 | metal-powder | 优秀 | Polvo Metálico | 金属粉 | A12_items_4 #12 |
| 61 | burn-heal | 优秀 | Antiquemar | 退热膏 | A12_items_4 #13 |
| 62 | ice-heal | 优秀 | Antihielo | 暖身贴 | A12_items_4 #14 |
| 63 | awakening | 优秀 | Despertar | 提神铃 | A12_items_4 #15 |
| 64 | lemonade | 优秀 | Limonada | 柠檬水 | A12_items_4 #16 |
| 65 | secret-key | 优秀 | Llave Secreta | 古祭坛钥匙 | A13_items_5 #1 |
| 66 | gold-teeth | 优秀 | Dentadura de Oro | 金牙套 | A13_items_5 #2 |
| 67 | old-rod | 优秀 | Caña Vieja | 旧钓竿 | A13_items_5 #3 |
| 68 | life-orb | 稀有 | Vidasfera | 生命宝珠 | A13_items_5 #4 |
| 69 | choice-band | 稀有 | Cinta Elección | 专注头带 | A13_items_5 #5 |
| 70 | choice-specs | 稀有 | Gafas Elección | 专注眼镜 | A13_items_5 #6 |
| 71 | choice-scarf | 稀有 | Pañuelo Elección | 专注围巾 | A13_items_5 #7 |
| 72 | expert-belt | 稀有 | Cinta Experto | 达人腰带 | A13_items_5 #8 |
| 73 | focus-band | 稀有 | Cinta Aguante | 坚持头巾 | A13_items_5 #9 |
| 74 | kings-rock | 稀有 | Roca del Rey | 王冠石 | A13_items_5 #10 |
| 75 | assault-vest | 稀有 | Chaleco Asalto | 突击背心 | A13_items_5 #11 |
| 76 | eviolite | 稀有 | Mineral Evol | 进阶晶石 | A13_items_5 #12 |
| 77 | exp-share | 稀有 | Repartir Exp | 经验共享坠 | A13_items_5 #13 |
| 78 | macho-brace | 稀有 | Brazal Firme | 负重护具 | A13_items_5 #14 |
| 79 | black-sludge | 稀有 | Lodo Negro | 黑泥瓶 | A13_items_5 #15 |
| 80 | star-piece | 稀有 | Trozo Estrella | 星辰碎片 | A13_items_5 #16 |
| 81 | stick | 稀有 | Puerro | 芦苇杖 | A14_items_6 #1 |
| 82 | razor-fang | 稀有 | Colmillo Agudo | 锐牙 | A14_items_6 #2 |
| 83 | shed-shell | 稀有 | Muda Concha | 蜕壳 | A14_items_6 #3 |
| 84 | cell-battery | 稀有 | Pila | 电池 | A14_items_6 #4 |
| 85 | lum-berry | 稀有 | Baya Ziuela | 青葡果 | A14_items_6 #5 |
| 86 | poke-doll | 稀有 | Poké Muñeco | 布偶玩偶 | A14_items_6 #6 |
| 87 | dowsing-machine | 稀有 | Zahorí | 寻宝探测器 | A14_items_6 #7 |
| 88 | bicycle | 稀有 | Bici | 自行车 | A14_items_6 #8 |
| 89 | iron-ball | 稀有 | Bola Férrea | 铁球 | A14_items_6 #9 |
| 90 | fresh-water | 稀有 | Agua Fresca | 清水瓶 | A14_items_6 #10 |
| 91 | full-heal | 稀有 | Cura Total | 全能药 | A14_items_6 #11 |
| 92 | guard-spec | 稀有 | Protección X | 护卫喷剂 | A14_items_6 #12 |
| 93 | coin-case | 稀有 | Monedero | 零钱包 | A14_items_6 #13 |
| 94 | focus-sash | 史诗 | Banda Aguante | 不屈腰带 | A14_items_6 #14 |
| 95 | pp-max | 史诗 | PP Máximos | 技能精华 | A14_items_6 #15 |
| 96 | max-elixir | 史诗 | Elixir Máximo | 全能灵药 | A14_items_6 #16 |
| 97 | shiny-stone | 史诗 | Piedra Día（星尘商店中文名：闪光之石） | 曦光晶 | A15_items_7 #1 |
| 98 | dusk-stone | 史诗 | Piedra Noche | 暮色晶 | A15_items_7 #2 |
| 99 | comet-shard | 史诗 | Fragmento Cometa | 彗星碎片 | A15_items_7 #3 |
| 100 | thunder-stone | 史诗 | Piedra Trueno | 雷晶 | A15_items_7 #4 |
| 101 | fire-stone | 史诗 | Piedra Fuego | 火晶 | A15_items_7 #5 |
| 102 | protector | 史诗 | Protector | 护甲板 | A15_items_7 #6 |
| 103 | griseous-orb | 史诗 | Griseosfera | 灰金宝珠 | A15_items_7 #7 |
| 104 | reaper-cloth | 史诗 | Tela Terrible | 幽影布 | A15_items_7 #8 |
| 105 | electirizer | 史诗 | Electrizador | 电能匣 | A15_items_7 #9 |
| 106 | ice-stone | 史诗 | Piedra Hielo | 冰晶 | A15_items_7 #10 |
| 107 | leaf-stone | 史诗 | Piedra Hoja | 叶晶 | A15_items_7 #11 |
| 108 | revive | 史诗 | Revivir | 复苏晶 | A15_items_7 #12 |
| 109 | ss-ticket | 史诗 | Ticket Barco | 船票 | A15_items_7 #13 |
| 110 | max-ether | 史诗 | Éter Máximo | 能量灵液 | A15_items_7 #14 |
| 111 | thick-club | 史诗 | Hueso Grueso | 粗木棒 | A15_items_7 #15 |
| 112 | rage-candy-bar | 史诗 | Caramelo Furia | 怒气糖棒 | A15_items_7 #16 |
| 113 | silph-scope | 史诗 | Visor Silph | 显影镜 | A16_items_8 #1 |
| 114 | max-revive | 传说 | Revivir Máximo | 大复苏晶 | A16_items_8 #2 |
| 115 | rare-candy | 传说 | Caramelo Raro（星尘商店中文名：神奇糖果） | 成长星糖 | A16_items_8 #3 |
| 116 | master-ball | 传说 | Master Ball（星尘商店中文名：大师球） | 必得徽印 | A16_items_8 #4 |
| 117 | moon-stone | 传说 | Piedra Lunar | 月晶 | A16_items_8 #5 |
| 118 | lustrous-orb | 传说 | Lustresfera | 珍珠宝珠 | A16_items_8 #6 |
| 119 | adamant-orb | 传说 | Diamansfera | 金刚宝珠 | A16_items_8 #7 |
| 120 | dawn-stone | 传说 | Piedra Alba | 晨曦晶 | A16_items_8 #8 |
| 121 | sun-stone | 传说 | Piedra Solar | 日晶 | A16_items_8 #9 |
| 122 | soul-dew | 传说 | Rocío Bondad | 灵露滴 | A16_items_8 #10 |
| 123 | silver-wing | 传说 | Ala Plateada | 银羽 | A16_items_8 #11 |
| 124 | rainbow-wing | 传说 | Ala Arcoíris | 虹羽 | A16_items_8 #12 |
| 125 | tm-case | 传说 | Estuche de MT | 招式卷宗 | A16_items_8 #13 |
| 126 | poke-flute | 传说 | Poké Flauta | 唤醒长笛 | A16_items_8 #14 |

A16 第 15、16 格是“空物品槽”和“锁定物品槽”（HUD 物品槽 3301/3318）。

### b9. 应用图标 / 商店图
- project.godot：config/icon="res://icon.png"，仓库快照里没有尺寸要求，也没有商店图配置。A17 是一张 1024 的应用图标概念稿（仅参考）。商店宣传图（feature graphic）在代码里没有出处，所以没写提示词。
- A18 启动图：代码里没有出处，属于可选项（见上文“加载”）。

## 占位 IP / 联想风险名（只说联想风险和改法，不下法律结论）

| 代码里的写法 | 位置 | 联想对象 | 建议改法 |
|---|---|---|---|
| 精灵球（付费宝箱） | 7255, 7599, 9494, 9495 | 宝可梦精灵球 | 付费宝箱 / 金箍宝箱 |
| 友情球 | 6031, 12710, profile.gd 256 | 宝可梦友友球 | 羁绊绳 / 结缘铃 |
| 超级球箱 | 10074, 10075, 10094 | 宝可梦超级球 | 守护者宝箱 |
| 喵喵 / 喵喵商店 / 黄金喵喵 / 喵喵在拜访 | 7459-7468, 7599, 9013 EVENT_DEFS, 9513, 16300 | 宝可梦喵喵 | 行商 / 商店；黄金喵喵改为“金币小贼” |
| 霹雳电球 | 9805 | 宝可梦霹雳电球 | 弹簧团子 |
| 皮卡丘（老虎机） | 9783 | 宝可梦皮卡丘 | 闪电符号 |
| 喵喵（老虎机） | 9795 | 同上 | 金币符号 |
| 耿鬼（老虎机） | 9802 | 宝可梦耿鬼 | 骷髅符号 |
| 百变怪 | 9651-9665, 9517 | 宝可梦百变怪 | 拟态团 |
| 多边兽 / 多边兽终端 | 9905, 9511 | 宝可梦多边兽 | 数据终端 |
| 卡比兽 | 9485 | 宝可梦卡比兽 | 沉睡巨兽 |
| 犀牛图腾 / 犀牛咆哮 | 10072, 10094 | 宝可梦独角犀牛 | 巨岩图腾 / 图腾咆哮 |
| 未知祭坛（及稀有/史诗/黄金）/ 未知图腾 | 48, 9958 | 宝可梦未知图腾 | 古石祭坛 / 古石图腾 |
| 树果 | 9549, 9788, 9481 | 宝可梦树果 | 野果 |
| 常磐森林 / Viridian Forest，紫苑塔 / Lavender Tower | 81, 100（暂停页 15814 同时显示中英文） | 宝可梦地名 | 翠叶森林、幽灯塔（岩石沙漠、火山岛是通用词，可以保留） |
| 闪光宝可梦 | profile.gd 481 | 直接写出品牌名 | 闪光伙伴 |
| 大师球 / 神奇糖果 / 幸运蛋 / 护符金币 / 甜甜蜜 / 闪光之石 | profile.gd 471-483（星尘商店） | 都是宝可梦官方中文道具名 | 必得徽印 / 成长星糖 / 福运蛋 / 招财护符 / 蜂蜜罐 / 曦光晶 |
| 126 件持有物品（西语名） | items.json | 全部是宝可梦道具 | 见 b8 表 |
| 11 种维生素 | game_data.gd 26-38 | 宝可梦能力提升道具 | 见 b7 表 |
| 妙蛙种子 / 小火龙 / 杰尼龟 等物种名，招式名（藤鞭、飞叶快刀、大字爆炎…） | 194-197, 169-179, model_rig.gd | 宝可梦官方中文名 | 物种和招式本身不在美术范围内，已转交文案。效果图里沿用 U3 的“撞击”“猛撞”，这两个也是官方招式名，有轻度联想 |
| 大招名（狂怒根须、疯狂藤蔓、爆裂燃烧…） | ult.gd NAMES_ZH 48 | PokéBonk 原作大招，部分接近官方招式名 | 交给文案 |
| 体系用词：特攻/特防、18 类型（含妖精、恶）、进化、闪光、阿尔法、收服、联盟、图鉴 | 多处 | 整套体系明显对应宝可梦 | 属于系统设计层面的问题，美术不改，只提示风险 |
| project.godot 描述 “PokéBonk structure” | project.godot | 直接写出原作名 | 发版前改掉 |
| UiIcon “ball”（红白球） | ui_icon.gd 115；world.gd 3019, 3805 | 精灵球外形 | 钱包改用钱包图形，宝箱价格改用宝箱图形 |

## 待定 / 需要确认
- 稀有度档数：暂停图例 15882 只列了 4 档（普通/稀有/史诗/传说），RARITY_NAMES 有 5 档（多一个“优秀”）。S18 照代码画 4 档，建议开发统一。
- 联盟挑战标题行 4891 直接显示 cfg["rank"]，而出战配置 16590 会把 rank 从英文翻成中文，所以 4891 可能露出英文 rank。效果图按中文画。
- _item_label 7266 用 “%s +%d%%” 格式，倍率小于 1 时会显示成 “最大生命 +-10%”（例如 life-orb、choice-band）。效果图避开了这些物品。
- 物品、星尘商店行在代码里都没有图标，效果图和 A09-A16 的图标属于建议新增。
- items.json 等补充文件来自本机拷贝，不是从仓库直接读的，需要以仓库原件复核。
- 示例名（苔团、砾壳、焰尾、拟态团、数据终端、翠叶森林、古石祭坛）和物品建议名都只是占位，最终以文案替换表为准。
