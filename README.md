# AGV Task Scheduling MATLAB Simulator

## 1. Project Goal
在固定 ProfControl 有向导航距离下研究多 AGV 任务排序。运行的是货物级取放离散事件，不模拟连续轨迹、路径规划、避障、路口冲突或途中改派。当前提供 FCFS、Random 和未来优化算法接口。

## 2. Original System
原系统 C# + ProfControl 负责真实 GoTo 和底层导航。MATLAB 是独立调度仿真器，导航可达不等于真实车辆 GoTo 可行性。

## 3. Exported Data
原始 stations.csv、lanes.csv、distance_matrix.csv、metadata.txt 只读。站点表每个 station/Pocket membership 一行，154 行对应 145 唯一站点；合法跨 Pocket membership 不作为重复站点错误。lanes 中 PocketKey/PocketName 以字符串读取，保留前导零与后缀。metadata 保存来源与导出语义。

## 4. Distance Model
距离来自 ProfControl NavigationShortestPath（导航缓存或有向图 Dijkstra）。D(i,j) 可以不等于 D(j,i)，禁止对称化。StationMark 通过 stationToIndex 映射，不直接作数组下标。NaN 保留，禁止填零或填路径。
当前 meterPerUnit=0.01（100 map unit=1m）是用户指定实验假设；metadata 的 MetersConversion 仍为 Unconfirmed，需要校准。速度单位 m/s；getTravelTime 是唯一距离到秒的换算入口。内部距离为 map unit，控制台距离转成米。Station 5 孤立，不能用于存货；所有车无法空载到取货位时方案不可行。

## 5. Lane Model
Sequence=0 在深处，数值越大越靠近入口，OrderStationsDirection=DeepToEntrance。只有 Slot 可以存货和取放；Entrance、Unknown 仅为结构/导航信息。取货及放货都要求该货位外侧所有 Slot 无货。
getSlotAccessStations 根据真实 PocketKey 与 Sequence 找外侧货位，不能把 PocketName 当唯一业务主键。货物表中的 PocketName/Sequence 是定位提示，启动时与真实 lanes 校验。

Lane 状态查询接口（阶段 2）均为独立函数，不缓存 frontier，阶段 3 通过 assessment 间接供可行性检查调用：

- `[station,sequence,cargoID] = getLaneFrontier(pocketKey,state,data)`：仅对指定 PocketKey 的 Slot 排序，读取实时 `state.occupancy`，复用 No-hole 校验后返回最大已占用 Sequence。空 Lane 返回 `NaN,-1,""`；未知或没有 Slot 的 Key 报 `AGV:LaneKey`。
- `cargo = getOuterCargo(pocketKey,state,data)`：返回 frontier 的一行 table，列为 `CargoID,StationMark,Sequence`；空 Lane 返回同列的零行 table。
- `[station,sequence,isAvailable] = getLegalDropSlot(pocketKey,state,data)`：返回 frontier Sequence+1 对应的真实 Slot；空 Lane 返回 Sequence 0，满 Lane 返回 `NaN,-1,false`。深度来自 `data.lanes`，该查询只判断库存位置，不包含预留或完整派单可行性。以后判断合法放货位置应使用此接口；`getSlotAccessStations` 继续用于查询入口方向的阻挡位置。
- `station = getCargoCurrentStation(cargoID,state)`：读取实时 `state.cargos`；AtSlot 返回 CurrentStation，OnAGV 返回 NaN，不存在报 `AGV:MissingCargo`。不读取静态任务起点或初始库存。

Lane 查询遇到内部空洞时报 `AGV:InternalHole`。

### Customer Task assessment（阶段 3 / v3.1）

`a = assessCustomerTask(task,data,state,customerTasks)` 是只读评估。第四个参数为完整 Customer Task table；省略时使用 `state.customerTasks`，再省略则只知道当前单条任务，无法识别其他 Future/Completed Cargo。任务目录保留原有 TaskID（不作行索引）；实时 `state.taskStatus` 按目录行顺序覆盖目录 Status，未提供实时状态时使用 Status，默认 Pending。`simulateSchedule` 仅在初始化时附加目录，未改主循环；尚不执行任何准备 Action。

assessment 字段：

- 标识：`CustomerTaskID, CargoID`。
- 实时位置：`SourceStation, SourcePocketKey, SourceSequence, TargetStation, TargetPocketKey, TargetSequence, SourceTargetSameLane`。
- Ready：`SourceReady, TargetReady, CustomerMoveReady`。
- 动作：`SourceAction, TargetAction, MainAction`；`SourceActionCargoID, SourceActionStation, TargetActionCargoID, TargetActionStation, TargetActionReason`；额外用 `MainActionCargoID, MainActionStation` 明确 R_SELF/CUSTOMER_MOVE 的货物和源位置。
- 准备详情：`RequiredFillingCount, NextFillingStation, ProtectedFutureCargoID, RequiresTemporarySelfRelocation, Reason`。无对应数值/字符串/标志使用 NaN/空字符串/false。

Source 使用 `getCargoCurrentStation` 的实时位置，不读 Initial PickupStation。OnAGV 立即返回 `CARGO_IN_TRANSIT` 且三个 Ready 均 false。不同 Lane 独立评估两端：Source 不是 outer cargo 时返回当前 outer 的 `R_SOURCE`；Target 按 `R_TARGET → R_FUTURE → FILLING → Ready` 顺序判断。Target 位于占用前缀内时返回当前 outer 的 `R_TARGET/TargetClearing`；否则检查更深处未完成 Customer Cargo，存在则返回当前 outer 的 `R_FUTURE/TerminalProtection`，并单独记录受保护货物（多个时优先标识最靠入口者）。普通 Cargo 和已完成的深层 Cargo 不主动触发 R_FUTURE。没有上述障碍时，Target 等于 legal drop 才 Ready；更外侧则返回 FILLING、Sequence 差值及下一个填充站，不选择填充货物。

两端可同时返回 Action，TargetPrep 优先只是后续调度偏好，不是 hard precedence。本阶段不排序、不派单。只有 SourceReady && TargetReady 且货物 AtSlot 时才能 `CUSTOMER_MOVE`，禁止先 Pickup 等待目标准备。Future Customer Cargo 可作为临时清障对象，评估不会完成其 Customer Task；任一应搬障碍若已 Completed，报 `AGV:CompletedCargoBlocked`，禁止再次搬动。

同 Lane 先清 Source。Customer Cargo 暴露后，只在 state 副本中移除源货物并评估 Target。可立即合法回填时返回 CUSTOMER_MOVE；否则仅暴露 R_SELF，目标端的原因、Filling 数量等保留为 post-pickup 分析详情，不同时执行目标准备。R_SELF 不是完成任务；临时搬到别的 Lane 后，下次查询实时位置自然进入不同 Lane 模式，不维护 phase。Compact 模型下同 Lane 直接完成的边界是回到原 Slot；现有 CSV 校验仍禁止源终点相同的正式请求，单元测试直接验证此评估边界。

`checkCargoTaskFeasible(task,data,state)` 保持三输出接口，以 assessment.CustomerMoveReady 为必要条件，再沿用原访问 footprint 和预留检查；非 Ready 时 reason 来自 assessment。assessment 本身不判断 Lane Lock、AGV、ReleaseTime 或 Business precedence。当前旧模拟器事件执行仍用静态 PickupStation；本阶段不会执行 Relocation，因此动态位置仅在 assessment/可行性接口验证，后续执行层改造另行进行。

阶段 4 已删除旧 Source precedence：Customer Task hard precedence 只来自最终 Target placement 与显式 business precedence（如有）。准备 Action 尚未接入正式 event engine，当前不可将整个模拟器视为已完成 v3.1 调度实现。

### Unified Relocation Action（阶段 5）

`R_SOURCE / R_TARGET / R_FUTURE / R_SELF` 统一为 `ActionType="RELOCATION"`，对应 `RelocationKind` 分别为 `SOURCE_CLEARING / TARGET_CLEARING / TERMINAL_PROTECTION / SELF_TEMPORARY`。区别在清障原因及 assessment 所属端，不使用四套搬运算法。

调用流程：Known Cargo → Query Real-time Source → Verify Cargo Accessible → Generate Feasible Target Lane Candidate Set → Select One Target Lane → LegalDropSlot Automatically Determined → Build One Relocation Action。

```matlab
assessment = assessCustomerTask(parentTask,data,state);
% 明确选择一端，不在 Builder 内实现 Target/Source 调度排序。
action = buildRelocationAction(parentTask,assessment,"SOURCE",state,data);
% TARGET 对应 R_TARGET/R_FUTURE；MAIN 对应 R_SELF；FILLING 不受理。
if action.IsFeasible
    nextState = applyRelocationCompletion(action,state,data); % 仅测试原子完成
    nextAssessment = assessCustomerTask(parentTask,data,nextState);
end
```

Relocation 接口要求 `state.customerTasks` 是完整 Customer Task 目录，以防漏掉 Completed Cargo；`state.taskStatus` 按目录行对齐并优先于目录 Status。`getRelocationSource(cargoID,state,data)` 统一查询实时 CurrentStation，确认 AtSlot、真实 Slot、当前 outer cargo，以及 Cargo 状态与 occupancy 一致。不可直接取时报 `AGV:RelocationCargoNotAccessible`，已完成货物报 `AGV:CompletedCargoBlocked`，缺任务目录报 `AGV:TaskState`。

`getRelocationCandidateLanes(cargoID,parentTask,kind,state,data)` 遍历所有真实 Storage PocketKey（仅 Slot），返回全部可行目标，而非直接挑最近的一条。表列为 `PocketKey, PocketName, DropStation, DropSequence, LoadedDistance, RemainingCapacity, IsParentTargetLane`；RemainingCapacity 表示本次假想放入后的剩余空 Slot 数。每条 Lane 自动绑定当前唯一 LegalDropSlot，不在 Lane 内另选位置。

硬过滤包括：当前 Source Lane、满 Lane、无有效/空的 LegalDropSlot、源/目标访问 footprint 的任何非零 reservation、无法保持 No-hole 的状态，以及 Source→DropStation 有向距离非有限或不可达。沿用现有保守预留语义，访问范围仍是端点及其入口方向所有 Slot；不修改或忽略现有预留，也不预先移动其他货物。SOURCE_CLEARING 额外排除 Parent 最终 Target Lane，避免重新破坏其 Target Preparation。候选 Lane 内有 Future 或深层 Completed Cargo，本身不是排除理由；禁止的是搬动 Completed Cargo。

`selectRelocationLaneBaseline(candidates)` 独立选择 LoadedDistance 最小行，距离相同按字符串 PocketKey 升序，再按 DropStation 升序，结果 deterministic。它只选择 Lane；Target Slot 使用候选行已绑定的位置。Nearest Loaded Distance 仅为当前 baseline，后续可替换为 Top-K + H-step Lookahead，本阶段未实现。

`buildRelocationAction(parentTask,assessment,side,state,data)` 每次只返回一个 struct：`ActionType, RelocationKind, ParentCustomerTaskID, CargoID, SourceStation, SourcePocketKey, SourceSequence, TargetStation, TargetPocketKey, TargetPocketName, TargetSequence, LoadedDistance, IsFeasible, Reason, ProtectedFutureCargoID, CreatedFromSide`。ParentCustomerTaskID 始终是被推进的 Parent，而不是被搬 Future Cargo 自己的任务。TERMINAL_PROTECTION 另外保留 ProtectedFutureCargoID；它可能不同于实际搬运的 CargoID。

Builder 重新 assess 以拒绝已过期请求，并在选择后再次检查实时 Source 与 Candidate 合法性。无候选时返回 `IsFeasible=false, Reason="No feasible relocation target lane"`，目标数值为 NaN，不判全局 DEADLOCK。过期 assessment 返回 infeasible；对非法取货和 Completed Cargo 则明确报错。

Relocation 采用滚动生成：每次只生成当前一个 Action。Move 完成、Warehouse State 更新后必须重新 assess，才决定下一步，绝不提前保存整条清障链。测试用 `applyRelocationCompletion(action,state,data)` 要求货物仍 AtSlot、源与目标仍有效且无预留冲突；它模拟整个 Move 已完成的原子更新（不是 OnAGV/事件回调）：清空源 occupancy，写入目标 occupancy，更新 Cargo.CurrentStation/Status=AtSlot/AGVID=0，并验证全仓 No-hole。它不修改任何 Customer Task Status/Completed、预留或优先级，不接入 simulateSchedule。

阶段 5 未实现 Filling、Relocation+Filling 合并、ReadySet、Dispatcher、AGV 分配、运行时 Relocation 事件执行、Top-K、H-step 或 Memetic；Target/Business 静态 hard precedence 保持不变。

### Filling Action（阶段 6）

Relocation 的方向是 Known Cargo → Choose Target Lane → LegalDropSlot Auto；Filling 则是 Known Target Slot → Choose Source Lane → Outer Cargo Auto。Filling 只搜索 Source Lane，不搜索 Cargo×Slot 组合。

```matlab
assessment = assessCustomerTask(parentTask,data,state);
if assessment.TargetAction == "FILLING"
    action = buildFillingAction(parentTask,assessment,state,data);
    if action.IsFeasible
        nextState = applyFillingCompletion(action,state,data); % 仅测试原子完成
        nextAssessment = assessCustomerTask(parentTask,data,nextState);
    end
end
```

`state.customerTasks` 必须提供完整 Customer Task 目录。**Filling Cargo = Ordinary Cargo only**：CargoID 必须不属于任何 Customer Task，包括 Parent、Pending、Future、InProgress 和 Completed；此规则不依赖任务 Status。Relocation 因真正挡路可以临时搬动 Future Cargo，Filling 是主动选货补结构，因此不允许选择任何 Customer Cargo。

分层接口：

- `getFillingTarget(parentTask,assessment,state,data)`：统一验证 Parent/assessment 身份，重新 assess；只有仍为 FILLING，且 NextFillingStation 与当前 Parent Target Lane 唯一 LegalDropSlot 一致才返回目标。不能由调用方另选 Slot。
- `[candidates,reason] = getFillingCandidateSourceLanes(parentTask,assessment,state,data)`：枚举全部 Storage PocketKey（仅 Slot）。每条非空 Source Lane 只对应实时 outer cargo；排除 Filling Target Lane、任何 Customer Cargo、非 AtSlot/实时位置与 occupancy 不一致、源/目标访问 footprint 预留冲突，以及有向距离 NaN/Inf/负值的候选。源端及目标端都沿用端点加入口方向全部 Slot 的现有预留语义，不新增或修改 reservation。
- `selectFillingSourceLaneBaseline(candidates)`：选择 LoadedDistance 最小行；并列按字符串 SourcePocketKey、SourceStation 升序，deterministic，不使用随机数。
- `buildFillingAction(parentTask,assessment,state,data)`：构造 ONE Filling Action，选择后重新检查 assessment、Source 和 Target；不生成整条 Filling chain，不改变 Customer priority 或 hard edges。
- `applyFillingCompletion(action,state,data)`：测试/后续复用的完整 Move 原子更新 helper，尚未接入 simulateSchedule；要求 cargo 仍 AtSlot、Source/Target 及访问预留仍合法，不是正在运输的事件回调。

Candidate table 列为 `SourcePocketKey, SourcePocketName, CargoID, SourceStation, SourceSequence, TargetStation, TargetPocketKey, TargetSequence, LoadedDistance, RemainingSourceCargoCount`；最后一项是取走该 outer cargo 后 Source Lane 的剩余货物数。Lane 深度来自真实 map，不假定统一长度。候选生成会在 state 副本模拟源空/目标有货，并验证全仓 No-hole。

Action 字段为 `ActionType="FILLING", ParentCustomerTaskID, CargoID, SourceStation, SourcePocketKey, SourceSequence, TargetStation, TargetPocketKey, TargetSequence, LoadedDistance, IsFeasible, Reason, CreatedFromSide="TARGET", RequiredFillingCountBefore`。ParentCustomerTaskID 表示正在推进的 Customer Task，不创建新的 Customer Task。

没有合法 Source 时返回 `IsFeasible=false, Reason="No feasible filling source lane"`，不退而选用 Customer Cargo，也不判全局 Deadlock。旧 assessment 的 TargetAction/NextFillingStation 已变化，或伪造了 Filling Target 时，返回 `IsFeasible=false, Reason="Stale assessment"`。原输入不是 FILLING 或不属于 Parent，报 `AGV:FillingAssessment`；缺完整目录报 `AGV:TaskState`。Completion 前再发现 Source、Target、普通货物身份或预留条件已变化，报 `AGV:StaleFillingAction`，不返回部分更新。

Filling Source 不能是 Target Lane：取走同 Lane outer 会使 frontier 后退，原 NextFillingStation 不再是 legal drop，放入将产生空洞。Parent 当前 Source Lane 则不机械排除：如果 outer 是普通 blocker，可正常用于 Filling，SourceReady 在之后重新 assess 时自然变化；如果 outer 是 Future/其他 Customer Cargo，仍禁止。Source 深处存在 Future/Completed Cargo 不导致整条 Lane 排除，只要实际取出的 outer 是普通货物且其他检查通过。

Filling 同样采用 rolling one-action generation：Build ONE Filling → Complete → Update state → Re-assess → Build next Filling if needed。例如需填两个位置，第一次只填当前 LegalDrop；重新 assess 后数量由 2 变 1，再构造下一次，最后 TargetReady=true。Completion 同时清空源 occupancy、写目标 occupancy、更新 CurrentStation/Status=AtSlot/AGVID=0，并验证 No-hole；不修改任何 Customer Task Status/Completed、预留或任务目录。

Nearest-loaded-distance 仅为 baseline，后续可替换为 Top-K + H-step lookahead。阶段 6 不接入主循环，不实现 ReadySet、多 AGV Dispatcher、主动 Relocation+Filling 合作评分、Top-K、H-step 或 Memetic；普通 Source blocker 顺便被清除只是合法状态变化，不增加特殊 ActionType 或奖励。

### Unified Runtime Action + ReadySet（阶段 7A）

Runtime flow：Customer Priority → Hard Predecessor Eligibility → assessCustomerTask → Build Current Runtime Actions → ReadySet →（下一阶段）Dispatcher → AGV Assignment。

```matlab
% priority 是任务表行索引 1:N 的完整排列，不是 TaskID。
% currentTime 默认 0；businessEdges 默认 0x2，沿用阶段 4 的行索引边。
ready = buildReadyActions(tasks,customerPriorityOrder,state,data,currentTime,businessEdges);
% ready.ActionPayload{k} 保留原始 CUSTOMER_MOVE / RELOCATION / FILLING struct。
```

`buildCustomerMoveAction(task,assessment,state,data)` 新增动态正式搬运 Action。构造前重新 assess，要求旧/新 assessment 均 CustomerMoveReady；通过 getCargoCurrentStation 查询实时 Source，验证 AtSlot、当前 outer cargo、最终 Target 当前为空且等于 legal drop、访问预留无冲突、有向载货距离有限非负，以及假想取放后 No-hole。绝不使用 task.PickupStation。旧 assessment 失效时返回 infeasible，不执行 Pickup/Dropoff，不标记 Completed。同站点请求仍遵守既有正式输入契约，不构造搬运动作。

Customer Move 字段为 `ActionType="CUSTOMER_MOVE", ParentCustomerTaskID, CustomerTaskID, CargoID, SourceStation, SourcePocketKey, SourceSequence, TargetStation, TargetPocketKey, TargetSequence, LoadedDistance, IsFeasible, Reason, CreatedFromSide="MAIN"`。三类 Runtime Action 共享基本搬运字段；RelocationKind、ProtectedFutureCargoID、RequiredFillingCountBefore 等扩展字段保留在各自 payload，不改阶段 5/6 接口。

`buildReadyActions` 每次从当前 snapshot 完整重建，流程如下：

- 按输入 priority 的任务行顺序遍历完整 Customer Task 表。优先使用 state 中实时状态，按 TaskID 对齐 state.customerTasks 目录；若无目录则将输入 tasks 作为完整目录，仅在局部副本中附加。输入任务及 state 均不修改。
- 只处理 Pending（兼容 NOT_COMPLETED）Parent；Completed、InProgress、PickedUp 等不重复暴露动作。ReleaseTime 尚未到达的任务跳过。Target/business hard predecessor 必须全部 Completed，未满足时该 Parent 的所有准备/正式动作都跳过，不因 Priority 高就提前准备。
- 不同 Lane 可同时贡献 Target-side R_TARGET/R_FUTURE/FILLING 和 Source-side R_SOURCE；两端分别调用已有 Builder，只有 IsFeasible=true 的动作才收集。无合法 Relocation/Filling 候选则省略该动作，不判 DEADLOCK，不完成 Parent。
- CustomerMoveReady 时该 Parent 只贡献 CUSTOMER_MOVE；R_SELF 时只贡献 SELF_TEMPORARY Relocation；CARGO_IN_TRANSIT 不生成重复动作。`validateRuntimeAssessment` 对 CustomerMoveReady 同时声称 preparation、或 R_SELF/运输中同时声称 preparation 等矛盾状态报 `AGV:RuntimeAssessment`。

ReadySet 是 table，列为 `ReadyActionID, ActionType, ParentCustomerTaskID, ParentPriorityRank, ActionSide, ActionSideRank, CargoID, SourceStation, SourcePocketKey, SourceSequence, TargetStation, TargetPocketKey, TargetSequence, LoadedDistance, ActionPayload`。ActionPayload 为 cell，保存原始 Action struct。ReadyActionID 采用 `T<TaskID>_<Side>_<ActionType>`，当前生成中唯一，同一任务/侧别/类型在同一 snapshot 重建时稳定；它不是 Customer TaskID，也不是跨时间的派发实例号。

ParentPriorityRank 是 Parent 在输入 priority 中的原始位置（较小优先），不会给 child action 新建 Customer Priority，也不会因部分任务被过滤而重新压缩 rank。ActionSideRank 为 MAIN=0、TARGET=1、SOURCE=2；同 Parent 的 TargetPrep 优先只是软偏好，不是 hard edge，两个无冲突动作都能保留。跨 Parent 首先比较 ParentPriorityRank。

`normalizeReadyActions` 按 ParentPriorityRank、ActionSideRank、ReadyActionID 升序做 deterministic greedy normalization：同 Cargo、同 SourceStation、同 TargetStation 的冲突只保留高优先级动作。只与已保留动作比较，暂时移除不代表失败，下一次 rebuild 可以再出现；不尝试重新选择 baseline 候选或全局最大匹配。共享 PocketKey/Lane 本身不是去重条件，后续 Dispatcher 再判断 Lane lock 和并行资源。

ReadySet 只是“当前逻辑上可执行、可交给 Dispatcher 考虑的 Action 集合”，不是“已经派发 Action”。Generation 完全只读：不修改 occupancy、CurrentStation、Cargo Status、Customer Completed、AGV、reservedBy 或 Lane lock。独立 Builder 不负责 hard predecessor/ReleaseTime，这些逻辑资格统一由 Collector 先检查。

不长期缓存 ReadySet。后续阶段 7B 应在 Pickup/Dropoff、Source Lane/预留释放、CurrentStation 变化、Relocation/Filling/Customer Move 完成、AGV idle、新任务到达等事件后重新构建。本阶段不添加 event hook，不接入 simulateSchedule，不实现 AGV Assignment、Dispatcher、Top-K、H-step 或 Memetic。

## 6. Manual Cargo and Task Inputs
配置文件路径统一在 config.m：cargoFile、taskFile。main 不再调用自动任务生成，也不会改写输入 CSV。详见 tasks/INPUT_GUIDE.md。

货物表 tasks/cargo_initial.csv 四列：StationMark,CargoID,PocketName,Sequence。列出 65 个 Slot，每个恰好一行。CargoID 空白表示空位，有值表示唯一货物；全部占用都必须填，包括不参与任务的障碍货。不能填字面值“空”，同名货物需加唯一编号。

任务表 tasks/tasks_input.csv：TaskID,CargoID,DropoffStation,ReleaseTime。TaskID 是唯一整数；CargoID 必须存在于初始货物表，且整个任务集中每件货物只出现一次；目标只能是 Slot，不能与源站相同。ReleaseTime 是相对仿真开始的下发秒数，当前建议全部 0；实际开始不能早于下发。

加载后 loadTaskConfiguration 根据 CargoID 推导 PickupStation，添加 TaskType=Transport、Status=Pending。输入表不包含起点，但运行表明确携带货物、起点和终点。

**USER CONFIGURATION REQUIRED**：用户自行填写货物与任务。任务引用的 CargoID 若未配置，会明确报 AGV:MissingCargo，不会生成虚拟货物。若采用初始例子，可将 C001 填到站点12，C002填到站点110，目标10、21保持空；源站应按实际实验修改。两件货物直接互换占用的 Slot 时，本版全程预留目的地且要求目标在派单时为空，无法无缓冲交换，返回目标占用原因。

## 7. Cargo, Slot and AGV State
Slot：occupancy 为 CargoID 或空字符串；reservedBy 是预留该货位的任务行索引。
Cargo：CargoID、CurrentStation、AGVID、Status；装车后站点为 NaN，状态 OnAGV；卸货后在目标 Slot，状态 AtSlot。
AGV：ID、CurrentStation、AvailableTime、TotalTravelDistance、TotalBusyTime、TaskHistory、CargoID、ActiveTask。容量固定一件，只有完整卸货后才能接新任务。AGV 连续位置未建模；CurrentStation 在取货/卸货事件更新，不代表行驶途中实时位置。

## 8. Current AGV Assignment Rule
车辆为 AGV02→站点2、AGV03→站点4、AGV04→站点0、AGV05→站点3。速度及服务时间共用配置，车队同质。
事件时刻扫描任务优先列表，找到可执行任务，在当前空闲车辆中使用 assignAGV 选择预计最早到达取货站的可达车辆；并列按配置排列。忙碌车辆不能提前接新任务。所有车忙碌时推进下一事件；无关巷道的任务可以并行。
这与旧版为未来可用车辆预先排队的分配模型不同，算法比较始终使用同一个当前规则。

## 9. Objective Function and Encoding
sequence 是任务表行索引 1:N 的完整排列，不是 CargoID、TaskID 或 StationMark。evaluateSequence 返回 makespan，第二输出完整 result；不可行方案返回 invalidCost，不伪造完成。
prioritySequence 为拓扑修复后的优先列表；finalSequence 为实际派单顺序，因暂时占用/阻挡，可能跳过高优先任务，或不可行时仅含已派单任务。遗传编码应使用完整优先排列，不能拿失败结果的部分 finalSequence 当完整染色体。

## 10. Constraints and Event Semantics
`buildTargetConstraints(tasks,lanes,businessEdges)` 按最终 DropoffStation 查找真实 Slot，以 PocketKey 分组、Sequence 升序排序，仅建立相邻深位→浅位任务边。Sequence=0 最深，因此更小 Sequence 的最终任务必须先完成。输出仍是任务行索引 N×2 边矩阵，保持 repairSequence、checkTaskFeasible、evaluateSequence 兼容。前置任务 Dropoff 完成后才释放后续任务。

旧规则“Source Lane 外层 Customer Task 必须先于内层 Customer Task”已经废弃。初始 Source、实时 CurrentStation、普通货物占用均不参与静态硬约束；Source blocking 由运行时 Relocation 解决（执行模块尚未实现）。**终端管硬顺序，源端管动态清障。**

可选 businessEdges 是显式任务行索引边，默认 0×2；本阶段不新增业务 CSV 或配置系统。Target 与 business 边合并后统一由 validateTaskPrecedence 检查强连通分量和自环，存在环时报 AGV:CyclicTaskPrecedence，列出实际环内 TaskID/CargoID。重复最终 TargetStation 在输入加载阶段报 AGV:DuplicateCustomerTarget，列出目标站和冲突的 TaskID/CargoID。不同 Target PocketKey 不自动产生边，PocketName 仅用于显示。buildLaneConstraints 只保留为兼容 wrapper，转发到新函数，不存在第二套 Source 约束。
任务派单时必须：货物在源站、目标为空、源外侧无货、目标外侧无货、访问货位未被其他任务预留。若任务从外侧搬到同巷道内侧，源货物在放货前已取走，不视为它对自身目的地的阻挡。
第一版保守预留源站、目标站和两端所有外侧 Slot，直到该任务卸货完成才释放。这样避免两车争抢空位、行驶期间新放入货物封堵访问，但会限制部分同巷道并行；这是货位访问资源规则，不是交通冲突模型。
Dispatch：预留访问货位并标记 AGV 忙碌；不提前移动库存。
Pickup：在空载行驶+Pick 完成时，源站变空，货物装上 AGV。
Dropoff：在载货行驶+Drop 完成时，目标占用更新，AGV 变空，释放预留。
每个事件时刻先处理完成事件，再派单。任务暂不可执行时继续尝试其他任务；若有活动任务或未来 ReleaseTime，则推进事件。剩余任务无法推进时报告每个任务的占用/阻挡/可达原因，返回惩罚，不自动增加障碍货搬运任务。
输入无效（货物缺失、重复、目标非 Slot 等）在 main 启动报明确错误；优化评估内的无效方案返回 penalty 和 failureReason。

## 11. MATLAB Project Structure
- main.m：读取手动输入、验证、两基线、输出。try/catch 保证失败时关闭 diary。
- config.m：物理、车辆、输入路径、种子、日志/绘图输出配置。
- data/loadSimulationData.m：读取真实原始导出。
- data/buildDistanceMatrix.m：唯一站点映射与完整有向距离矩阵。
- data/validateInputData.m：原始数据、车辆配置、任务路径与约束检查。
- data/validateCargoConfiguration.m：所有 Slot、唯一货物、手动任务检查。
- data/buildTargetConstraints.m：最终 Target 深→浅相邻任务硬约束及可选业务边。
- data/validateTaskPrecedence.m：统一 DAG 校验和环内任务报告。
- data/buildLaneConstraints.m：弃用名称的兼容 wrapper，转发 Target 约束。
- tasks/loadTaskConfiguration.m：只读加载两个 CSV，补起点和运行字段。
- tasks/cargo_initial.csv：用户初始全部货位占用。
- tasks/tasks_input.csv：用户正式搬运请求。
- tasks/INPUT_GUIDE.md：填写规则。
- tasks/generateExampleTasks.m、tasks/tasks_example.csv：旧站点运输示例，已停用，不适用于货物级模型。
- simulator/initializeCargoState.m：每次评估创建独立初始库存，算法间互不污染。
- simulator/getSlotAccessStations.m：找外侧 Slot。
- simulator/checkCargoTaskFeasible.m：货物、目标容量、阻挡、预留检查，不含算法逻辑。
- simulator/simulateSchedule.m：派单/Pickup/Dropoff 事件推进与输出。
- simulator/evaluateSequence.m：统一优化目标接口。
- simulator/repairSequence.m、checkTaskFeasible.m：优先拓扑修复、固定前置检查。
- simulator/assignAGV.m：固定最早到达分车规则，调用方仅传当前空闲车辆。
- simulator/getTravelDistance.m、getTravelTime.m：有向查距、时间换算。
- algorithms/fcfsSequence.m、randomSequence.m：输入行顺序、随机完整排列。
- algorithms/algorithmTemplate.m：未来算法输出 bestSequence,bestFitness,history 的占位模板。
- visualization/：甘特图、利用率、摘要；只为可行方案绘图。
- tests/runTests.m：真实地图与临时输入，验证库存和调度，不改用户输入。

## 12. How to Run and Outputs
先填写两张 CSV，再打开 MATLAB：
~~~matlab
cd('C:/Users/huhan/Desktop/AGV_Simulation')
main
~~~
resultFCFS/resultRandom 保存 makespan、距离、时间、车辆分配、taskStatus、constraints、prioritySequence、finalSequence、taskTable、eventLog、finalSlotState、finalCargoState、agvs。
result.assignedAGV 是内部车索引，assignedAGVID 是实际车号。
results 中每种算法输出 *_tasks.csv、*_events.csv、*_slots.csv、*_cargo.csv、*_status.txt；可行时生成 *_gantt.png、*_utilization.png；保存 simulation_results.mat、precedence_constraints.csv、run_log.txt。每次覆盖同名输出，旧图可能来自上次可行运行，判断本次请先看 *_status.txt。results 不提交 Git。
~~~matlab
run('tests/runTests.m')
~~~
测试在 results 下生成临时 CSV，结束清除，不要求当前用户配置可行，不覆盖 cargo_initial.csv 或 tasks_input.csv。

## 13. How to Add a New Optimization Algorithm
仅生成完整任务索引排列，调用 evaluateSequence。不可行结果参与 penalty 评价。不要把算法写进仿真器；不要自动增加用户任务或改输入文件。
~~~matlab
candidate = randperm(height(tasks));
[fitness,result] = evaluateSequence(candidate,tasks,data,cfg);
~~~
动态占用与阻挡会让不同优先级产生不同派单顺序或可行性；不能假设只做一次拓扑排序即可保证可行。

## 14. Known Assumptions
固定有向距离、速度、Pick/Drop 时间；每 Slot 一件货，每 AGV 一件货；任务集每 CargoID 一次。无充电、实时交通、重量差异、额外临时挪货。访问货位全程保守预留；前置任务 Drop 完成释放后续任务。输入中的占用是真实初始状态，未列货名表示空位。

## 15. Known Data Notes
145 unique stations、154 membership rows、34 physical pockets、65 unique Slots、21025 directed pairs、288 NaN；Station 5 isolated。Sequence=0 deepest，货物 CSV 按巷道名称与深度升序方便填写。

## 16. Future Work
GA/GWO/SA/ACO/禁忌搜索，多目标、动态插单、联合 AGV 分配。障碍货搬运应由独立模块生成临时任务，届时可放宽正式任务/临时任务的货物重复规则，并动态更新货物位置和未执行任务起点；不能把初始起点写死到未来任务。

### 任务时序动画

运行 `main` 后，`results/fcfs_animation.html` 和 `results/random_animation.html` 可直接用浏览器离线打开。通过 `config.m` 的 `enableAnimation` 开关导出，`animationSpeed` 设置每秒播放推进的仿真秒数（默认 5）。支持播放/暂停、倍速、拖动时间、回到开始和下一事件，包含站点、AGV、全部初始货物、装卸进度、同步时间轴及任务明细。

站点按巷道分组，站点间连线仅表示任务运输关系；车辆在连线上按真实任务阶段时长插值移动，不表示实际导航路径或真实比例。货物在 Pickup 完成时离开源站，在 Dropoff 完成时进入目标站，与仿真库存事件一致。未参与任务的货物也会显示。受阻方案显示原因且仅回放已派单工作，不使用 penalty makespan 作为动画时长，不伪造任务完成。

`run('tests/runTests.m')` 会额外生成 `results/animation_demo.html`，使用隔离测试数据演示并行运输；该文件不是当前用户输入的调度结果。输入 CSV 不会被修改。

### PPT 用 GIF 动图

`main` 同时生成 `results/fcfs_animation.gif` 和 `results/random_animation.gif`。在 PowerPoint 中选择“插入 → 图片 → 此设备”，选择 GIF，进入幻灯片放映即可播放。GIF 是循环播放的固定动画，不包含 HTML 播放控件。

配置集中在 `config.m`：`enableAnimationGIF` 控制导出；`gifResolution=[1920 1080]` 设置尺寸；`gifFPS=8` 设置帧率；`gifMaxDuration=20` 限制运动播放时长，较长的排程会整体加速，任务并行与先后关系保持不变。默认按 `animationSpeed` 播放，开头停留约 1 秒，结尾停留约 2 秒。`gifShowAllStations=true` 默认显示全部巷道货位与库存，车辆配色与浏览器一致，并使用小车图标、车辆状态卡和同步时间轴；设为 `false` 可聚焦任务起终点和车辆初始站点。

HTML 与 GIF 共用 `buildAnimationData` 的调度时间数据。GIF 中 AGV 在站点连线上移动，装货完成后货物随车、卸货完成后货物留在终点，并显示车辆状态和同步时间轴。受阻且未派单的排程导出静态 GIF，显示受阻原因。GIF 保存在已忽略的 `results` 目录，另有 `*_animation.gif` 忽略规则，生成文件不提交 Git。

## 17. AI Modification Guidelines
先读 README。禁止修改原始 CSV 或用户手动输入、对称化距离、填 NaN、把 Unknown 当 Slot、用站点号直接索引。参数放 config；算法解耦；修改货位预留/事件时间/容量/任务规则同步文档和测试。原始 metadata 与用户物理比例假设保持区分。新增临时搬运之前不能伪造障碍货已被移走。

初始库存采用 Compact Storage / No-hole：Sequence=0 为最深处，数值越大越靠近入口。逐条真实 PocketKey，只对 Slot 按 Sequence 升序检查，CargoID 非空表示占用，占用向量必须为 `[1 ... 1 0 ... 0]`。空巷道和满巷道合法；空位后再次有货时报 `AGV:InternalHole`，包含 PocketName、PocketKey、两处 Sequence/StationMark 及 CargoID。独立函数 `data/validateNoHoleState.m` 接收当前货物表和 lanes，方便以后重复调用；本阶段只接入初始加载校验。

示例若在站点12、110放货，巷道01、02的 Sequence 0–5 也必须连续有货，不能仅在最外层放货。
