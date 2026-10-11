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
buildLaneConstraints 仍生成同巷道现有取货任务的外→内前置边，并通过 repairSequence 修复。只有实际任务参与固定前置边；非任务货物的阻挡通过真实 occupancy 判断。前置任务全部卸货完成后后续取货任务才释放，这是保守业务规则。
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
- data/buildLaneConstraints.m：取货任务外→内前置边。
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

## 17. AI Modification Guidelines
先读 README。禁止修改原始 CSV 或用户手动输入、对称化距离、填 NaN、把 Unknown 当 Slot、用站点号直接索引。参数放 config；算法解耦；修改货位预留/事件时间/容量/任务规则同步文档和测试。原始 metadata 与用户物理比例假设保持区分。新增临时搬运之前不能伪造障碍货已被移走。
