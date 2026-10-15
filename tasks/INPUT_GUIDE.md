# 手动货物与任务配置

这两张表已接入 main.m，是当前货物级仿真的只读输入。程序根据初始货物补出取货站，检查货位占用、单车容量、两端外侧阻挡及预留；无法推进时返回不可行及具体原因，不自动挪走障碍货。

## cargo_initial.csv

根据 stations.csv 的 IsCargoSlot=1 提取全部 65 个唯一 Slot，并核对 lanes.csv 的 StationType=Slot 一致；原始文件没有修改。

每行一个真实货位，只编辑 CargoID 列：填写唯一货物名/编号表示有货，留空表示空位。不要填写字面值“空”，避免将其当成货物编号。相同货物名不能出现在两个货位；若两件货物同品名，请用“货物A_001”“货物A_002”等唯一标识。未参与搬运的障碍货也必须填写。

表格只保留 StationMark、CargoID、PocketName、Sequence 四列，按 PocketName 升序，同一巷道按 Sequence 升序（深处到入口）排列。StationMark 是货位站点号，PocketName、Sequence 是只读定位信息；Sequence 越大越靠近入口。不要增加非 Slot 行，不要改变站点号或删除空位行。用表格软件编辑时，将 PocketName 保持为文本，保留前导零。

## tasks_input.csv

任务表提供两条可修改的示例：

```csv
TaskID,CargoID,DropoffStation,ReleaseTime
1,C001,10,0
2,C002,21,0
```

第一条表示把 C001 搬到 Slot 10；第二条表示把 C002 搬到 Slot 21，均从时间 0 下发。货物配置表仍保留原有 CargoID，不会自动放入示例货物。若使用这些例子，可在 StationMark=12 的行填写 C001，在 StationMark=110 的行填写 C002，并保持目标 10、21 为空；这两个源站分别属于巷道 01、02 的最外侧 Slot。其他货位占用仍应按实际情况填写。

这些是填写示例；两条任务配合站点12的 C001、站点110的 C002 和空目标10、21，已通过真实地图事件仿真测试。用户需自行配置货物初始位置；任务引用未配置货物时启动会报 AGV:MissingCargo。互换两个已占用货位时，本版需要额外缓冲搬运，否则报告目标占用。CargoID 必须与货物配置表完全一致，任务集中每件货物最多出现一次；TaskID 唯一；DropoffStation 必须是 Slot；ReleaseTime 单位秒，当前静态实验全部填 0。不要在任务表放空白占位行。

加载后的运行任务表根据货物初始位置补出 PickupStation，同时保存目标站、任务类型和状态。输入文件只读，程序不能自动重写用户配置。目标是否为空、外侧是否阻挡应按运行时状态检查，不能仅凭 CSV 路径可达就认为可执行。未来障碍货搬运任务会独立生成，并按实际货物位置更新未执行任务起点。

初始库存采用 Compact Storage / No-hole：Sequence=0 为最深处，数值越大越靠近入口。逐条真实 PocketKey，只对 Slot 按 Sequence 升序检查，CargoID 非空表示占用，占用向量必须为 `[1 ... 1 0 ... 0]`。空巷道和满巷道合法；空位后再次有货时报 `AGV:InternalHole`，包含 PocketName、PocketKey、两处 Sequence/StationMark 及 CargoID。独立函数 `data/validateNoHoleState.m` 接收当前货物表和 lanes，方便以后重复调用；本阶段只接入初始加载校验。

示例若在站点12、110放货，巷道01、02的 Sequence 0–5 也必须连续有货，不能仅在最外层放货。