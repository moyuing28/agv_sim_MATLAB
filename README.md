# AGV Task Scheduling MATLAB Simulator

## 1. Project Goal
在固定 ProfControl 有向导航距离下研究多 AGV 任务排序。运行的是货物级取放离散事件，不模拟连续轨迹、路径规划、避障、路口冲突或途中改派。当前 main.m 是 FCFS 与 GS-Memetic 正式对比实验的唯一手动入口。后续将在现有仿真器外部开发传统 Memetic Algorithm（遗传算法 + 局部搜索），优先最小化 SystemMakespan，并在相同条件下比较搬运次数和总距离；目前已完成 GS/TS 编码、遗传算法主体、首次改进局部搜索及全局评价预算控制，已完成小预算联调并将正式参数集成到 main.m；完整正式优化尚待用户运行验证。

## 2. Original System
原系统 C# + ProfControl 负责真实 GoTo 和底层导航。MATLAB 是独立调度仿真器，导航可达不等于真实车辆 GoTo 可行性。

## 3. Exported Data
原始 stations.csv、lanes.csv、distance_matrix.csv、metadata.txt 只读。站点表每个 station/Pocket membership 一行，154 行对应 145 唯一站点；合法跨 Pocket membership 不作为重复站点错误。lanes 中 PocketKey/PocketName 以字符串读取，保留前导零与后缀。metadata 保存来源与导出语义。

## 4. Distance Model
距离来自 ProfControl NavigationShortestPath（导航缓存或有向图 Dijkstra）。D(i,j) 可以不等于 D(j,i)，禁止对称化。StationMark 通过 stationToIndex 映射，不直接作数组下标。NaN 保留，禁止填零或填路径。
当前 meterPerUnit=0.01（100 map unit=1m）是用户指定实验假设；metadata 的 MetersConversion 仍为 Unconfirmed，需要校准。速度单位 m/s；getTravelTime 是唯一距离到秒的换算入口。内部距离为 map unit，控制台距离转成米。Station 5 孤立，不能用于存货；所有车无法空载到取货位时方案不可行。

## 5. Lane Model

卸货后的车辆收尾：DropoffTime/CompletionTime 仍为货物实际卸货完成时刻，Customer Task 同时按原规则完成，Target reservation 释放。车辆进入 ExitingLane，继续持有 Target Lane lock，按有向距离从货位驶向该 PocketKey 的真实 Entrance。到入口后进入 AtEntrance，由当前 ReadySet 和现有分车规则决定接续；同车重新进入同巷道时原 MoveID 的锁直接交接给新 MoveID。未获可派发动作的入口车辆释放锁并 ReturningHome，抵达自身初始站点后 Idle，途中不抢占。Source Pickup 立即释放的流水机制不变。

退出和返程复用同一个 Runtime 事件循环，不生成货物 Move。新增 ExitStart/ExitArrival、TargetReservationReleased、LaneLockHandoff、ReturnHomeStart/HomeArrival；TargetReleased 现在表示入口离开时真正释放锁。ExitDistance、ReturnHomeDistance 是地图距离单位，计入 emptyDistance、totalDistance 和 AGV 忙碌时间各一次。CustomerCompletionMakespan 截止客户完成，SystemMakespan 等待必要退出/返程结束。Move CSV 的 VehicleFinishTime 表示该次车辆收尾结束（入口接续或返 Home），不改变 DropoffTime。HTML/GIF 使用相同的实际 Runtime 时间展示退出、返程及 Home 停留。
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

同 Lane 先清 Source。Customer Cargo 暴露后，只在 state 副本中移除源货物并评估 Target。可立即合法回填时返回 CUSTOMER_MOVE；否则仅暴露 R_SELF，目标端的原因、Filling 数量等保留为 post-pickup 分析详情，不同时执行目标准备。R_SELF 不是完成任务；临时搬到别的 Lane 后，下次查询实时位置自然进入不同 Lane 模式，不维护 phase。阶段 7C 已将已在最终 Slot 的情况单独识别为 AlreadyAtFinalTarget，进行 terminal protection / FINALIZE，不再进行原地取放；初始已在 Target 的任务也允许经过 eligibility 后 FINALIZE。

`checkCargoTaskFeasible(task,data,state)` 保持三输出接口，以 assessment.CustomerMoveReady 为必要条件，再沿用原访问 footprint 和预留检查；非 Ready 时 reason 来自 assessment。assessment 本身不判断 Lane Lock、AGV、ReleaseTime 或 Business precedence。阶段 7B 执行层已改为读取 Running Move 的动态 Source/Target；静态 PickupStation 只在初始输入校验与旧 assignAGV 参数兼容分支保留，不用于 Runtime Move 取放。

阶段 4 已删除旧 Source precedence：Customer Task hard precedence 只来自最终 Target placement 与显式 business precedence（如有）。阶段 7B 已接入三类 Runtime Action 的 baseline 离散事件执行；尚未实现 Top-K/H-step/Memetic。

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

Runtime flow：Customer Priority → Hard Predecessor Eligibility → assessCustomerTask → Build Current Runtime Actions → ReadySet → Dispatcher → AGV Assignment（阶段 7B 已接入）。

```matlab
% priority 是任务表行索引 1:N 的完整排列，不是 TaskID。
% currentTime 默认 0；businessEdges 默认 0x2，沿用阶段 4 的行索引边。
ready = buildReadyActions(tasks,customerPriorityOrder,state,data,currentTime,businessEdges);
% ready.ActionPayload{k} 保留原始 CUSTOMER_MOVE / RELOCATION / FILLING struct。
```

`buildCustomerMoveAction(task,assessment,state,data)` 新增动态正式搬运 Action。构造前重新 assess，要求旧/新 assessment 均 CustomerMoveReady；通过 getCargoCurrentStation 查询实时 Source，验证 AtSlot、当前 outer cargo、最终 Target 当前为空且等于 legal drop、访问预留无冲突、有向载货距离有限非负，以及假想取放后 No-hole。绝不使用 task.PickupStation。旧 assessment 失效时返回 infeasible，不执行 Pickup/Dropoff，不标记 Completed。初始已在 Target 的任务同样走零搬运完成；阶段 7C 已停用原地确认式 Customer Move，运行时 AlreadyAtFinalTarget 通过 terminal protection / FINALIZE 处理，Relocation 本身仍不完成 Customer。

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

不长期缓存 ReadySet。阶段 7B 已在初始化、每次 dispatch commit、Pickup/Dropoff/预留释放和 AGV idle 后重建。ReleaseTime 仍作为固定输入的释放时刻处理；不实现动态新任务重优化、Top-K、H-step 或 Memetic。

### 多 AGV Runtime 离散事件执行（阶段 7B）

Runtime pipeline：Customer Priority → Hard Eligibility → Assess → Build ReadySet → Dispatcher → Select Action → Assign AGV → Reserve Source/Target → Travel to Source → Pickup → Release Source → Loaded Travel → Wait outside Target if needed → Dropoff → Release Target → Update State → Rebuild ReadySet。

沿用 simulateSchedule 单一事件时钟、原始有向距离、getTravelTime、cfg.pickTime/dropTime、容量一件的 AGV 状态。没有第二套模拟器、连续轨迹或新路径算法。createRuntimeMove 保存 ActionPayload 和冻结的 Source/Target；processRuntimeEvents 将原有 Pickup/Dropoff 更新扩展为所有 Action 共用的事件处理。每个 Move 保存一个 NextEventTime，时钟推进到最近事件或固定 ReleaseTime；同 timestamp 优先处理完成事件，再按 MoveID 稳定处理到达事件，清空零时长事件后才派发。

**Dispatcher**：使用原始 Customer Priority（行索引 permutation），由阶段 4 Target/business hard eligibility 过滤，不恢复 Source precedence。按 ParentPriorityRank、ActionSideRank、ReadyActionID 扫描，资源不可 commit 或没有可达 Idle AGV 时继续扫描后续 Action。Action-first、AGV-second。assignAGV 复用既有时间参数，比较 empty travel + pickup + loaded travel + dropoff 的预计完成时间，平局选数值 AGVID 最小者。

每 commit 一次立即重建 ReadySet，而不是给 N 台 Idle AGV一次分发旧集合前 N 行。新的 MoveID 递增唯一，作为 execution/reservation owner；ReadyActionID 仍是 snapshot 的逻辑标识，可在滚动清障中重复出现。同一个 Cargo、Source 或 Target 不会被两个 running moves 重复占用。新 reservation 会让低优 child builder 重选第二合法 Lane；不修改 baseline 候选评分或 Customer Priority。

**Reservation != Lane Lock**。Dispatch 只记录 Running Move、建立 Source/Target access-footprint reservation、设置 AGV ActiveMoveID/状态和预计事件，不修改 occupancy。到 Source 才获得 Source Lane lock，处理 cfg.pickTime；Pickup 完成后验证 AtSlot、真实 Source、outer cargo、容量和 owner，清空源、Cargo→OnAGV/CurrentStation=NaN/AGVID，验证 No-hole，立即释放 Source lock 和 Source reservation。Source resource release at pickup completion, not at final dropoff。项目没有独立 exit duration，handling 完成即视为退出，退出耗时为 0；未改距离或添加虚构退出行驶时间。

Target reservation 保持整个运输阶段，保护原 LegalDropSlot。到达 Target 后若物理 Lane lock 忙，AGV 在 Lane 外 WaitingTarget，保留目标逻辑预约而不持有 Source lock；lock 释放后再开始 Dropoff。Dropoff 前及完成时检查目标空、owner、当前 legal drop 和 No-hole，不另选 Slot。完成后写目标、Cargo→AtSlot/CurrentStation=Target/AGVID=0，释放 Target reservation/lock，AGV→Idle。独立锁等待逻辑已有事件 helper 测试；端到端 baseline 的保守 footprint reservation 通常会提前排除同 Lane 竞争，因此不会为演示等待而削弱预约保护。

CUSTOMER_MOVE 在最终 Target Dropoff 后将 Parent 标为 Completed 并记录 taskFinishTime；阶段 7C 另有零搬运 FINALIZE 完成路径。RELOCATION/FILLING 不改变 Parent 或 Future Cargo 自身的任务完成状态，R_SELF 后仍 Pending。下一次直接按 CurrentStation 重新 assess，不维护永久 same-lane phase，不预生成清障或 Filling chain。阶段 7C 已完全删除 Parent preparation completion barrier。同 Parent 的后续准备及 CUSTOMER_MOVE 仅由实时状态和资源决定，可以在前一个 preparation 仍运输时开始。所有 Customer 完成后，事件引擎继续收尾已派发 Move。

边界：Future Cargo 的临时 Relocation 允许恰好落在其最终 Target，但不完成其 Customer Task。阶段 7C 改为该任务 eligible 后通过 FINALIZE 零搬运确认，彻底停用 Source==Target 的确认式 CUSTOMER_MOVE。已移除旧 SameStation 禁止规则，初始或运行时 AlreadyAtFinalTarget 均由 FINALIZE 处理。

**WAIT/DEADLOCK**：不能派新 Action 但有 Running Move/未来事件时，推进最近事件并等待，WaitCount 计数，不误报 Deadlock。仅未完成 Customer 且没有 running/future event/可派发动作时返回 isDeadlocked=true，invalidCost 与详细 failureReason。diagnoseRuntimeDeadlock 保存逐任务 assessment、动作不可行原因、完整 Lane occupancy、reservation/lock；Running Move 却没有任何可释放资源的未来事件属于 AGV:RuntimeEventState 一致性错误，不静默判 Deadlock。运行时取放 invariant 失败报 AGV:RuntimeConsistency。

输出兼容：旧 taskStartTime/taskPickupFinishTime/taskFinishTime、assignedAGV/assignedAGVID、taskTable/finalSequence 表示正式 Customer Move；taskTable.Pickup 是实际正式搬运 Source。result.moves 保存所有完整 ActionPayload 与事件状态，runningMoves 在正常结束时为空；moveTable 导出 MoveID、ReadyActionID、ActionType、RelocationKind、ParentTaskID、CargoID、AGVID、Source/Target、Dispatch/Pickup/Dropoff/CompletionTime、距离和 Filling 数量。eventLog 保留原六列，并新增 MoveID、ActionType、SourceReserved/TargetReserved、LaneOwner、CargoStatus、ParentStatus；Pickup/Dropoff 对所有 Move 都记录。finalState 提供最终 Warehouse/locks，finalSlotState 的旧 ReservedByTaskIndex 列作为兼容别名保留，并新增 ReservedByMoveID，owner 均为 MoveID。

TotalMoveCount、RelocationCount、FillingCount、CustomerMoveCount 按已完成 Move 统计；距离包含三类 Move 的空载/载货距离，busy time 包含等待。CustomerCompletionMakespan=max(Customer taskFinishTime)，SystemMakespan 为所有已派发 Move 和 Customer 完全结束的 simulation time；makespan=SystemMakespan，用于 evaluateSequence/Cmax。正常结束所有 Cargo AtSlot、AGV Idle、reservation/lock 全清。main 额外导出 *_moves.csv；HTML/GIF/Gantt 根据所有 Runtime Moves 回放，支持同一 Cargo 多次临时搬运，不再把固定 task.PickupStation 当执行端点。旧 assignAGV 的 task 参数兼容分支及初始输入校验仍可读取初始位置，正式执行链只传 Runtime Action。

阶段 7B 不实现 Top-K、H-step、Memetic、动态新任务重优化或主动 Relocation+Filling 协同优化。

### Source-release pipeline 与 Already-at-Final-Target（阶段 7C）

Runtime Move：Dispatch → Reserve Source + Target → Lock Source → Pickup → Release Source immediately → Loaded Travel → Lock Target → Dropoff → Release Target reservation → ExitingLane → AtEntrance → 接续任务或 ReturningHome。**Reservation != Lane Lock**。Source 仍使用 Pickup 完成即释放的原流水语义；Target lock 保留到真实入口离开或原子交接，不随 Dropoff 提前释放。

已删除 simulateSchedule 中按相同 ParentCustomerTaskID 扫描 Running preparation 并跳过 CUSTOMER_MOVE 的逻辑。Preparation 不需要完整 Dropoff 才允许 Parent 后续 Action：任何类型 Cargo 完成 Pickup 后，occupancy/CurrentStation/Status 和源资源变化立即生效，重新 assess/build ReadySet。只有实时 Cargo 状态、outer、legal drop、hard eligibility、reservation/lock 和可达性限制后续动作；不保留或变相恢复 Parent barrier，也不改 hard edges。

`assessCustomerTask` 新增 `AlreadyAtFinalTarget`、`FinalizeReady`。尚未 Completed 的 Cargo 为 AtSlot、CurrentStation 等于自身 final Target，且 occupancy 一致时进入独立 Already-at-final 分支，不将自己误判为 R_TARGET，也不因占用自己的目标要求 R_SELF。更深处有 unfinished Customer Cargo 时仍返回当前 outer 的 `R_FUTURE/TERMINAL_PROTECTION`，保留 ProtectedFutureCargoID；深处 Completed Cargo 不主动移动。

No-hole 仍是硬约束：若该 C 本身挡在更深 Future Cargo 前面，当前真正可搬的 outer 可能就是 C。必须先把 C 临时移走，不能越过 C 直接抽取深层 Cargo；C 离开后 AlreadyAtFinalTarget=false，后续按实时位置继续准备和搬运。只有 C 仍在（或经合法后续 Move 再次到达）final Target，且保护需求消失时才能 FINALIZE，不会为满足日志序列而传送 C 或伪造完成。

`buildFinalizeAction(task,assessment,state,data)` 构造 `ActionType="FINALIZE"` 的零搬运 Runtime Action，具有 Parent/CustomerTaskID、CargoID、实时 Source/Target、LoadedDistance=0、IsFeasible/Reason、CreatedFromSide=MAIN。它只读且不创建 Move。若该 Cargo 已有尚未完成 Pickup 的 Move reservation，则暂不冻结 Cargo，避免把已预约待搬的货物提前标为 Completed；不因其他无冲突 AGV 忙碌而等待。

FINALIZE 按 ParentPriorityRank 进入 ReadySet，Collector 先检查 ReleaseTime 和现有 Target/business hard predecessor。Dispatcher 即使所有 AGV Busy 也继续扫描 FINALIZE；不调用 assignAGV、不申请 Source/Target reservation/lock，不创建 MoveID、不产生 Pickup/Dropoff 或 travel/handling time。每次成功 Finalize 后同 timestamp 重新 build ReadySet，已完成 Parent 不再生成新 child Action。

`applyCustomerFinalize(action,state,data,currentTime,businessEdges)` 在执行前重新检查 Pending、ReleaseTime、hard predecessors、AtSlot、CurrentStation/occupancy、terminal protection 和 FinalizeReady。成功仅更新 state.taskStatus 和 taskCompletionTime；不修改 occupancy、Cargo.CurrentStation/Status、AGV 或任何资源。完成后由既有 Completed Cargo 保护机制禁止再次搬动。Relocation 落在自己的最终目标仍不自动完成，其任务必须单独通过上述资格和优先级处理。

日志与指标：finalizeLog 单独记录 Time、TaskID、CargoID、TargetStation、BusyAGVCount、ParentPriorityRank、ReadyActionID，main 导出 *_finalize.csv。FinalizeCount 单独计数，不增加 TotalMoveCount/RelocationCount/FillingCount/CustomerMoveCount。finalized task 的 assignedAGV=0、PickupFinishTime=NaN，CompletionType=FINALIZE；正式搬运任务为 CompletionType=CUSTOMER_MOVE。

CustomerCompletionMakespan 是最后一个 Customer taskCompletionTime；SystemMakespan 是所有已派发 Runtime Move、Customer、AGV 载货及 reservation/lock 完全结束的最终时刻。兼容字段 makespan 采用 SystemMakespan，evaluateSequence 因而评价系统 Cmax；agvUtilization 分母也采用系统时间。Customer 完成后不新建其 child，但必须继续处理已有 Move 到 Dropoff/资源释放，不能在 Customer 完成时强行退出或取消尾部运输。

测试包含三 AGV 的 T B C 流水、Target clearing / R_FUTURE / Filling source 流水、Finalize eligibility 和 terminal protection、AGV 全 Busy 时 Finalize，以及 CustomerCompletionMakespan=100/SystemMakespan=120 的实际执行场景。阶段 7C 不实现 Top-K、H-step、Memetic、动态任务重优化或主动协同优化，不修改地图、路径或 Target/business hard precedence。

### Relocation + Filling Cooperation（阶段 8.1）

当同一 Parent 同时存在 `TargetAction=="FILLING"`（目标 Lane 需要填充）与 `SourceAction=="R_SOURCE"`（源被阻挡）时，`buildFillingAction` 在 `selectFillingSourceLaneBaseline` 的最近距离 baseline 之上增加一层协同优先：若 `assessment.SourceActionCargoID`（源阻挡货物）当前是合法 Filling candidate，则 Filling 直接选择该阻挡货物。这样一次 FILLING Move 在物理上同时完成“清源”与“填缝”，随后 `normalizeReadyActions` 按 CargoID 冲突去掉多余的 SOURCE_CLEARING，不会重复搬运。

触发条件严格限定为：`SourceAction == "R_SOURCE"` 且阻挡货物出现在 `getFillingCandidateSourceLanes` 的合法候选中。阻挡货物属于任何 Customer Cargo（含 Future/Completed/Pending/InProgress）、已不在 Source outer、被 reservation、不可达、No-hole 不通过或任一现有 Filling 约束不满足时，协同偏好自动失效，完整回退到原来的最近距离 Filling 选择；此时 SOURCE_CLEARING Relocation 仍按原路径独立生成。

该改动只影响 Filling 的 Source 选择偏好，不新增 ActionType，协同 Move 仍记录为 `FILLING`。Future Cargo / Terminal Protection、Target/business hard precedence、No-hole、reservation、Lane lock、每次 commit 后强制重建 ReadySet、Pickup 后立即释放 Source Lane 及 FINALIZE 语义均保持不变；未修改地图、路径规划或现有硬约束。

新增 4×4 验收场景 A08_cooperation：T_COOP 在 L1 被普通货物 B_COOP 阻挡，目标 203 需要 1 次 Filling；另一普通货物 O_COOP 可作 Filling 源且按曼哈顿距离比 B_COOP 更近。协同开启时唯一 FILLING 选择 B_COOP（102→202），随后 T_COOP 正式搬运（101→203），共 2 次 Move；无 B_COOP 的 SOURCE_CLEARING。对照基线（关闭协同偏好）为 3 次 Move：O_COOP→202 Filling、B_COOP→301 SOURCE_CLEARING、T_COOP→203。当前单 AGV A08 场景实测：协同开启 TotalMoveCount=2、总距离 1300、SystemMakespan=33；关闭协同 TotalMoveCount=3、总距离 2500、SystemMakespan=55。这些数字仅来自该单 AGV 场景，不代表所有地图和多 AGV 场景都能获得同等收益；多 AGV 下并行执行可能缩小 makespan 差异。

## 6. Manual Cargo and Task Inputs
配置文件路径统一在 config.m：cargoFile、taskFile。main 不再调用自动任务生成，也不会改写输入 CSV。详见 tasks/INPUT_GUIDE.md。

货物表 tasks/cargo_initial.csv 四列：StationMark,CargoID,PocketName,Sequence。列出 65 个 Slot，每个恰好一行。CargoID 空白表示空位，有值表示唯一货物；全部占用都必须填，包括不参与任务的障碍货。不能填字面值“空”，同名货物需加唯一编号。

任务表 tasks/tasks_input.csv：TaskID,CargoID,DropoffStation,ReleaseTime。TaskID 是唯一整数；CargoID 必须存在于初始货物表，且整个任务集中每件货物只出现一次；目标只能是 Slot，不能与源站相同。ReleaseTime 是相对仿真开始的下发秒数，当前建议全部 0；实际开始不能早于下发。

加载后 loadTaskConfiguration 根据 CargoID 推导 PickupStation，添加 TaskType=Transport、Status=Pending。输入表不包含起点，但运行表明确携带货物、起点和终点。

**USER CONFIGURATION REQUIRED**：用户自行填写货物与任务。任务引用的 CargoID 若未配置，会明确报 AGV:MissingCargo，不会生成虚拟货物。若采用初始例子，可将 C001 填到站点12，C002填到站点110，目标10、21保持空；源站应按实际实验修改。两件货物直接互换占用的 Slot 时，本版全程预留目的地且要求目标在派单时为空，无法无缓冲交换，返回目标占用原因。

## 7. Cargo, Slot and AGV State
Slot：occupancy 为 CargoID 或空字符串；reservedBy 是预留该货位的任务行索引。
Cargo：CargoID、CurrentStation、AGVID、Status；装车后站点为 NaN，状态 OnAGV；卸货后在目标 Slot，状态 AtSlot。
AGV：ID、CurrentStation、AvailableTime、TotalTravelDistance、TotalBusyTime、TaskHistory、MoveHistory、CargoID、ActiveTask、ActiveMoveID、Status。TaskHistory 记录各 Move 的 Parent 行索引，MoveHistory 记录唯一 MoveID。容量固定一件，完成卸货并到达入口后才能接新任务。CurrentStation 在取货、卸货、入口及 Home 到达事件更新，不代表行驶途中实时位置。

## 8. Current AGV Assignment Rule
车辆为 AGV02→站点2、AGV03→站点4、AGV04→站点0、AGV05→站点3。速度及服务时间共用配置，车队同质。
事件时刻按 ParentPriorityRank、ActionSideRank、ReadyActionID 扫描 ReadySet，先选择可派发 Action，再从 Idle AGV 中通过 assignAGV 选择预计完成时间最早者；并列按实际 AGVID 升序。高优 Action 暂不可达或资源冲突时继续扫描低优 Action。每成功 commit 一次都重建 ReadySet；忙碌车辆不提前接新 Move。
这与旧版为未来可用车辆预先排队的分配模型不同，算法比较始终使用同一个当前规则。

## 9. Objective Function and Encoding
sequence 是任务表行索引 1:N 的完整排列，不是 CargoID、TaskID 或 StationMark。evaluateSequence 返回 makespan，第二输出完整 result；不可行方案返回 invalidCost，不伪造完成。
prioritySequence 保留输入的 Customer 优先列表（hard eligibility 单独过滤，不重写 priority）；finalSequence 为实际派单顺序，因暂时占用/阻挡，可能跳过高优先任务，或不可行时仅含已派单任务。TS 是传入仿真器的完整任务行索引优先排列；GS 是算法操作的目标 PocketKey 标签序列，不能拿失败结果的部分 finalSequence 当完整染色体。

### GS/TS 编码基础（Memetic 阶段 1）

GS 的每个基因是目标巷道 PocketKey，出现次数等于该巷道客户任务数。每条巷道的任务列表按目标 Sequence 升序（深到浅）固定，直接沿用 `buildTargetConstraints` 的规则。解码从左到右消费各巷道列表，返回任务行索引 TS；不依赖 TaskID 连续性，不硬编码 demo50。

| 接口 | 职责 |
|---|---|
| `buildGSMapping(tasks,lanes,businessEdges)` | 动态构建任务行、目标标签/Sequence、巷道固定列表、标签计数和原有静态前驱边；businessEdges 可省略 |
| `encodeTS(ts,mapping)` | 校验完整排列及全部静态前驱边，返回行字符串向量 GS |
| `decodeGS(gs,mapping)` | 校验标签、计数和全部静态前驱边，返回任务行索引 TS |
| `[gs,ts] = validateGS(gs,mapping)` | 明确拒绝非法输入，返回规范行向量，不自动修复 |
| `gsCanonicalString(gs,mapping)` | 生成长度前缀规范字符串，正确区分多位数标签及标签边界 |

```matlab
addpath('data','tasks','algorithms');
cfg = config();
data = loadSimulationData(cfg);
[tasks,~] = loadTaskConfiguration(data,cfg);
mapping = buildGSMapping(tasks,data.lanes);
% 每条巷道内按固定列表消费；该示例适用于默认无跨巷道 businessEdges 的映射。
gs = mapping.taskPocketKey';
ts = decodeGS(gs,mapping);
assert(isequal(encodeTS(ts,mapping),gs));
key = gsCanonicalString(gs,mapping);

addpath('tests');
testGSEncoding;
```

无法识别的目标 Slot、模糊巷道归属、空 PocketKey、非有限 Sequence、同巷道目标 Sequence 并列均报错。TS 必须完整且满足静态前驱关系；GS 的标签及出现次数必须准确，附加跨巷道 businessEdges 也必须满足。输入改变后应重建 mapping。原始 FCFS 不经过编码、修复或强制转换；动态 No-hole、Future Cargo protection、Relocation、Filling 和资源冲突仍由原仿真器负责。

当前 demo50 从真实输入得到 10 个客户任务、9 个标签，PocketKey `90` 的固定任务行列表为 `[2,10]`，静态边为 T2→T10。仅有巷道内约束时，合法 GS 数量按 `factorial(n)/prod(factorial(mapping.counts))` 动态计算，当前为 1,814,400；额外跨巷道前驱边可能进一步减少合法数量。

MATLAB R2022a 已通过独立编码测试（往返、多组合法 GS、非法输入、规范字符串及小规模排列枚举）和完整 `tests/runTests.m` 回归，A01–A08 全部通过。接口细节见 [algorithms/GS_ENCODING.md](algorithms/GS_ENCODING.md)。上述为阶段 1 的交付范围；阶段 2 已补充遗传算法、交叉、变异和运行内缓存，见下节。

### 遗传算法主体（Memetic 阶段 2）

阶段 2 在 GS 模块外部新增独立 GA，不改变原始 FCFS、仿真器或正式实验入口。主接口为 `runGSGeneticAlgorithm(mapping,evaluator,overrides)`，评价器接收解码后的 TS，返回候选指标；输出包含 `best`、最终 `population`、逐代 `history`、`options` 和运行 `stats`。真实适配器 `gaEvaluateSimulation(ts,tasks,data,cfg)` 直接复用 `simulateSchedule`，不导出正式结果。

参数集中在 `gaOptions`：初始/下一代种群 12、每代子代 8、锦标赛规模 3、交叉概率 0.8、交换变异概率 0.2；默认代数上限 5、种子 1、位置差异阈值 0.2、初始化尝试上限 10,000，均可通过 overrides 调整。独立 RandStream 不修改全局随机状态；可注入评价器自行负责其随机副作用。

- **初始化**：随机生成满足静态约束的拓扑任务排列，再编码为 GS，以规范键保证 12 个不同个体；空间上界不足或有限尝试耗尽时明确诊断，不无限循环。
- **选择与交叉**：锦标赛无放回抽取个体，按统一规则选优。交叉保留父代 A 的连续片段，再按父代 B 顺序及剩余标签配额补齐；跳过交叉时复制 A。
- **交换变异**：交换两个不同位置，保持标签总计数。交叉、变异后调用阶段 1 校验；违反附加跨巷道前驱边时拒绝该操作，保留操作前 GS，不自动修复。
- **统一排序**：可行优于不可行；可行候选依次最小化 SystemMakespan、TotalMoveCount、totalDistance，最后按规范键破并列。不可行候选按真实已完成客户数降序、规范键升序排列，未知进度排在已知进度之后；真实适配器仅从 `taskStatus=="Completed"` 计算进度，不把部分时间或 invalidCost 当作完工时间。
- **运行内缓存**：`gaCreateEvaluator` 使用 `gsCanonicalString` 作为键，命中时不重复调用评价器。分别记录送入缓存的候选数、唯一评价数和命中数，三者满足“候选数 = 唯一评价数 + 命中数”；初始化原始尝试和被拒绝的操作另计，不实现跨运行缓存。
- **精英与多样性**：父子代合并后按键去重，强制保留最优个体；按评价顺序扫描，仅接受与所有已选 GS 的不相同位置比例均达到阈值的候选。不足 12 个时按评价顺序补齐，始终保持键唯一。阈值设为 0 可关闭距离筛选。

独立测试命令（不运行真实完整优化）：

```matlab
addpath('tests');
testGSGeneticAlgorithm;   % 模拟评价器，少量代数
testGAEvaluationAdapter; % 短 A06 场景的真实适配器校验
testGSEncoding;          % 阶段 1 回归
run('tests/runTests.m');  % 既有完整回归
```

MATLAB R2022a 验证：固定种子的三代模拟运行生成 36 个候选，唯一评价 22 次、缓存命中 14 次，两次完整运行结果精确一致；关闭交叉和变异的两代测试为 12 次唯一评价、16 次命中。独立测试覆盖重复标签交叉、变异计数、非法前驱拒绝、去重、排序并列、多样性补齐、精英保留和缓存统计。真实适配器在 A06 FINALIZE 场景中与直接仿真的投影字段逐字段 `isequaln` 一致；阶段 1 和完整回归通过，A01–A08 全部通过。这些结果验证算法逻辑，不代表真实调度优化收益。

接口明细见 [algorithms/GS_GENETIC_ALGORITHM.md](algorithms/GS_GENETIC_ALGORITHM.md)。阶段 3 已补充局部搜索、评价预算和停滞停止，见下节；阶段 4A 已完成独立小预算联调，阶段 4B 将正式调用集成到 main.m，尚未运行完整正式实验。

### 首次改进与预算控制（Memetic 阶段 3）

沿用 `runGSGeneticAlgorithm`，每代从已评价父子代的合并集合选最优个体，调用 `gaFirstImprovement`。邻域按 `(1,2)、(1,3)…(N-1,N)` 固定顺序交换任意两个位置，同标签直接跳过，静态约束不合法的候选跳过。用原优化指标顺序判断严格改善（规范键仅用于排序，不构成改善），首次改善即接受并结束；否则保留起点。精英保留和多样性筛选继续复用阶段 2。

参数仍集中于 `gaOptions`：`maxUniqueEvaluations=100`、`localSearchEvaluations=3`、`enableStallStop=true`、`stallGenerations=4`。所有评价共享同一个 `gaCreateEvaluator` 缓存和计数器；缓存未命中时，在调用评价函数之前检查并预占预算。初始化、子代和局部搜索共同消耗唯一评价预算，命中不消耗。局部搜索每代最多新增 3 次唯一评价，用完额度后仍可接受后续缓存邻居的改善。MATLAB 异常向外抛出，不伪装成不可行调度。

预算不足时只使用已评价个体完成更新，允许不足 8 个子代或不足 12 个已评价初始个体。停止原因区分预算耗尽、搜索空间耗尽、初始化候选不足、连续若干代无改善、达到最大代数及连续若干代无新评价；“无新候选”诊断不代表已穷尽全部合法空间。关闭 `enableStallStop` 后仍有硬预算、最大代数和候选不足保护。

历史记录增加每代/全局最优 SystemMakespan、最优 GS/TS、可行性、实际子代数量、局部邻居尝试数、新增评价数、改善标志、累计评价/命中数、停滞代数和最终停止原因。不可行方案的完工时间保留 NaN。完整接口、计数口径及停止优先级见 [algorithms/GS_MEMETIC_ALGORITHM.md](algorithms/GS_MEMETIC_ALGORITHM.md)。

```matlab
addpath('tests');
testGSMemeticAlgorithm; % 合成映射和模拟评价器，含 100/1/0 预算边界
```

阶段 3 模拟测试以固定种子在第 29 代恰好达到 100 次唯一评价、累计 549 次缓存命中，正常以 `budgetExhausted` 返回；重复运行精确一致且不改变全局 RNG。阶段 1/2 测试和短 A06 适配检查通过，完整回归及 A01–A08 通过。未运行 demo50 完整优化、正式 FCFS 对照或阶段 4 实验。

### 真实仿真接入（阶段 4A）

新增独立入口 `runGSMemeticExperiment(overrides,outputDirectory)`，复用原始 FCFS、GS 模块、`gaEvaluateSimulation` 和 `simulateSchedule`，加载相同 demo50 输入、地图及 AGV 配置。默认仅 3 次唯一 GS 评价、最多 2 代，不修改正式参数。搜索不导出文件；结束后对最优 TS 额外复算一次，要求缓存指标逐字段 `isequaln` 一致。规范键仍用于确定性排序，但不同 GS 的全部优化指标相同时，不再视为严格改善。

真实小预算联调请在独立 MATLAB 进程中单独运行 `addpath('tests'); smokeGSExperiment`，不要并入混合测试进程。正式输出由可选的 `exportGSMemeticExperiment` 在搜索结束后处理，必须使用新目录，不覆盖现有 FCFS 文件，并复用原有事件/搬运记录、HTML/GIF 和绘图功能。完整说明见 [algorithms/GS_EXPERIMENT.md](algorithms/GS_EXPERIMENT.md)。本阶段不执行 100 次正式优化或形成论文实验结论。

### main 正式入口（阶段 4B，仅准备代码）

在 MATLAB R2022a 打开 `main.m` 点击 Run，程序会通过现有 `runGSMemeticExperiment` 顺序执行一次原始 FCFS、一次 GS 搜索、一次最优 TS 复算。main 不重复调用 FCFS 或仿真器。顶部参数为种群 12、子代 8、锦标赛 3、交叉 0.8、交换变异 0.2、首次改进每代最多 3 次新评价、全局唯一评价上限 100、种子 42、停滞停止关闭、最大代数 100；算法默认参数不变。

初始化完成（第 0 代）及每代完成后显示代数、唯一评价使用量、缓存命中、全局最优 SystemMakespan 和可行性。搜索期间不写正式文件；最优缓存指标逐字段精确复算通过后，才向新的独立目录导出。总距离同时显示地图单位与按实际 cfg.meterPerUnit 换算的米；不可行/死锁状态保留，不能计算改善率时显示不可用。

本轮只做静态接口及 Git diff 检查，未启动 MATLAB、未执行 main、仿真、优化、导出或回归测试；正式运行及输出效果待用户验证。文件清单和调用说明见 [algorithms/GS_EXPERIMENT.md](algorithms/GS_EXPERIMENT.md)。

## 10. Constraints and Event Semantics
`buildTargetConstraints(tasks,lanes,businessEdges)` 按最终 DropoffStation 查找真实 Slot，以 PocketKey 分组、Sequence 升序排序，仅建立相邻深位→浅位任务边。Sequence=0 最深，因此更小 Sequence 的最终任务必须先完成。输出仍是任务行索引 N×2 边矩阵，保持 repairSequence、checkTaskFeasible、evaluateSequence 兼容。前置任务 Dropoff 完成后才释放后续任务。

旧规则“Source Lane 外层 Customer Task 必须先于内层 Customer Task”已经废弃。初始 Source、实时 CurrentStation、普通货物占用均不参与静态硬约束；Source blocking 由运行时 Relocation 解决。**终端管硬顺序，源端管动态清障。**

可选 businessEdges 是显式任务行索引边，默认 0×2；本阶段不新增业务 CSV 或配置系统。Target 与 business 边合并后统一由 validateTaskPrecedence 检查强连通分量和自环，存在环时报 AGV:CyclicTaskPrecedence，列出实际环内 TaskID/CargoID。重复最终 TargetStation 在输入加载阶段报 AGV:DuplicateCustomerTarget，列出目标站和冲突的 TaskID/CargoID。不同 Target PocketKey 不自动产生边，PocketName 仅用于显示。buildLaneConstraints 只保留为兼容 wrapper，转发到新函数，不存在第二套 Source 约束。
任务派单时必须：货物在源站、目标为空、源外侧无货、目标外侧无货、访问货位未被其他任务预留。若任务从外侧搬到同巷道内侧，源货物在放货前已取走，不视为它对自身目的地的阻挡。
两端仍使用端点及所有外侧 Slot 的 access-footprint reservation，owner 为 MoveID。Source 在 Pickup 完成后立即释放；Target 持续保护至 Dropoff 完成。独立 Lane lock 保护 handling 及卸货后的真实退出，不等于全程 reservation。派单须检查目标/源巷道锁，不能让其他 AGV 进入尚在退出的巷道。
Dispatch：预留访问货位并标记 AGV 忙碌；不提前移动库存。
Pickup：在空载行驶+Pick 完成时，源站变空，货物装上 AGV。
Dropoff：在载货行驶+Drop 完成时，目标占用更新，AGV 变空，释放预留。
每个事件时刻先处理完成事件，再派单。任务暂不可执行时继续尝试其他任务；若有活动任务或未来 ReleaseTime，则推进事件。剩余任务无法推进时报告每个任务的占用/阻挡/可达原因，返回惩罚，不自动增加障碍货搬运任务。
输入无效（货物缺失、重复、目标非 Slot 等）在 main 启动报明确错误；优化评估内的无效方案返回 penalty 和 failureReason。

## 11. MATLAB Project Structure
- main.m：唯一手动正式入口，配置参数并调用 runGSMemeticExperiment；复算一致后统一导出到新目录，异常直接报告。
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
- simulator/assignAGV.m：已选 Action 的最早预计完成分车规则，调用方仅传当前空闲车辆，AGVID 并列破同。
- simulator/getTravelDistance.m、getTravelTime.m：有向查距、时间换算。
- algorithms/fcfsSequence.m、randomSequence.m：输入行顺序、随机完整排列；randomSequence.m 保留供独立使用，main.m 不再调用。
- algorithms/algorithmTemplate.m：未来算法输出 bestSequence,bestFitness,history 的占位模板。
- visualization/：甘特图、利用率、摘要；只为可行方案绘图。
- tests/runTests.m：真实地图与临时输入，验证库存和调度，不改用户输入。

## 12. How to Run and Outputs
先填写两张 CSV，再打开 MATLAB：
~~~matlab
cd('C:/Users/huhan/Desktop/AGV_Simulation')
main
~~~
experiment.resultFCFS / experiment.bestResult 保存 makespan、距离、时间、车辆分配、taskStatus、constraints、prioritySequence、finalSequence、taskTable、eventLog、finalSlotState、finalCargoState、agvs。
result.assignedAGV 是内部车索引，assignedAGVID 是实际车号。
每次 main 运行输出到新的 results/gs_memetic_<时间戳>_<唯一标识>/，不会覆盖已有文件。两组方案使用 fcfs、gs_memetic 前缀导出任务、事件、搬运、最终库存、FINALIZE 和状态；另存 comparison.csv、best_gs.csv、best_ts.csv、convergence.csv、search_history.csv、precedence_constraints.csv、run_log.txt 和 experiment.mat。HTML、甘特图、利用率和收敛图遵守输出开关；甘特图和利用率只为可行方案生成。results 不提交 Git。
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
固定有向距离、速度、Pick/Drop 时间；每 Slot 一件货，每 AGV 一件货；任务集每 CargoID 一次。无充电、实时交通、重量差异、额外临时挪货。Source/Target 分阶段释放保守访问预留；前置任务 Drop 完成释放后续任务。输入中的占用是真实初始状态，未列货名表示空位。

## 15. Known Data Notes
145 unique stations、154 membership rows、34 physical pockets、65 unique Slots、21025 directed pairs、288 NaN；Station 5 isolated。Sequence=0 deepest，货物 CSV 按巷道名称与深度升序方便填写。

## 16. Future Work
GA/GWO/SA/ACO/禁忌搜索，多目标、动态插单、联合 AGV 分配。障碍货搬运应由独立模块生成临时任务，届时可放宽正式任务/临时任务的货物重复规则，并动态更新货物位置和未执行任务起点；不能把初始起点写死到未来任务。

### 任务时序动画

运行 `main` 后，新实验目录中的 `fcfs_animation.html` 和 `gs_memetic_animation.html` 可直接用浏览器离线打开。通过 `config.m` 的 `enableAnimation` 开关导出，`animationSpeed` 设置每秒播放推进的仿真秒数（默认 5）。支持播放/暂停、倍速、拖动时间、回到开始和下一事件，包含站点、AGV、全部初始货物、装卸进度、同步时间轴及任务明细。

站点按巷道分组，站点间连线仅表示任务运输关系；车辆在连线上按真实任务阶段时长插值移动，不表示实际导航路径或真实比例。货物在 Pickup 完成时离开源站，在 Dropoff 完成时进入目标站，与仿真库存事件一致。未参与任务的货物也会显示。受阻方案显示原因且仅回放已派单工作，不使用 penalty makespan 作为动画时长，不伪造任务完成。

`run('tests/runTests.m')` 会额外生成 `results/animation_demo.html`，使用隔离测试数据演示并行运输；该文件不是当前用户输入的调度结果。输入 CSV 不会被修改。

### PPT 用 GIF 动图

启用 `enableAnimationGIF` 后，`main` 在新实验目录生成 `fcfs_animation.gif` 和 `gs_memetic_animation.gif`。在 PowerPoint 中选择“插入 → 图片 → 此设备”，选择 GIF，进入幻灯片放映即可播放。GIF 是循环播放的固定动画，不包含 HTML 播放控件。

配置集中在 `config.m`：`enableAnimationGIF` 控制导出；`gifResolution=[1920 1080]` 设置尺寸；`gifFPS=8` 设置帧率；`gifMaxDuration=20` 限制运动播放时长，较长的排程会整体加速，任务并行与先后关系保持不变。默认按 `animationSpeed` 播放，开头停留约 1 秒，结尾停留约 2 秒。`gifShowAllStations=true` 默认显示全部巷道货位与库存，车辆配色与浏览器一致，并使用小车图标、车辆状态卡和同步时间轴；设为 `false` 可聚焦任务起终点和车辆初始站点。

HTML 与 GIF 共用 `buildAnimationData` 的调度时间数据。GIF 中 AGV 在站点连线上移动，装货完成后货物随车、卸货完成后货物留在终点，并显示车辆状态和同步时间轴。受阻且未派单的排程导出静态 GIF，显示受阻原因。GIF 保存在已忽略的 `results` 目录，另有 `*_animation.gif` 忽略规则，生成文件不提交 Git。

## 4×4 Runtime Acceptance Dataset (Stage 7D)

`acceptance/4x4/` 是独立的 synthetic deterministic validation map，不是 ProfControl 正式地图。L1–L4 各有四个 Slot，Sequence=0 最深、3 最靠入口；StationMark 分别为 101–104、201–204、301–304、401–404，入口为 105/205/305/405，Home 为 1–4。静态距离 CSV 包含全部 576 个有向 Manhattan 距离，无 NaN。Home 坐标相同，为多车流水提供相同空载到达条件，分车仍使用原 AGVID tie-break。

从项目根目录运行：

```matlab
addpath('acceptance/4x4');
[summary,runs] = runAcceptance4x4();
```

A01–A07 分别验证 Source 流水、Target 流水、两次滚动 Filling、R_SELF、Terminal Protection 与后继 FINALIZE、初始 FINALIZE、双端并行和 commit 后候选重选。固定 Customer priority，不比较优化算法。输出在 `results/acceptance_4x4/`，包括 Markdown 报告、汇总 CSV、Move/Event/最终库存、FINALIZE、任务快照、ReadySet 回放证据、逐断言结果和完整诊断 MAT。逐场景捕获失败，继续后续场景；`testAcceptance4x4` 对任意 FAIL 报错，并已接入原回归末尾。

`config.m` 默认地图路径仍指向原正式文件；`loadSimulationData` 优先读取 cfg 的 stationFile/laneFile/distanceFile/metadataFile，旧 cfg 缺少字段时回退 projectRoot 原路径。只有 `acceptanceConfig4x4` 切换到验收地图和场景输入，关闭图像与动画。正常 `main` 仍读取正式大地图，验收不会覆盖正式地图或 Cargo/Task 输入。baseline 选择器和 Runtime 算法未修改。

## 17. AI Modification Guidelines
先读 README。禁止修改原始 CSV 或用户手动输入、对称化距离、填 NaN、把 Unknown 当 Slot、用站点号直接索引。参数放 config；算法解耦；修改货位预留/事件时间/容量/任务规则同步文档和测试。原始 metadata 与用户物理比例假设保持区分。新增临时搬运之前不能伪造障碍货已被移走。

初始库存采用 Compact Storage / No-hole：Sequence=0 为最深处，数值越大越靠近入口。逐条真实 PocketKey，只对 Slot 按 Sequence 升序检查，CargoID 非空表示占用，占用向量必须为 `[1 ... 1 0 ... 0]`。空巷道和满巷道合法；空位后再次有货时报 `AGV:InternalHole`，包含 PocketName、PocketKey、两处 Sequence/StationMark 及 CargoID。独立函数 `data/validateNoHoleState.m` 接收当前货物表和 lanes，方便以后重复调用；本阶段只接入初始加载校验。

示例若在站点12、110放货，巷道01、02的 Sequence 0–5 也必须连续有货，不能仅在最外层放货。
