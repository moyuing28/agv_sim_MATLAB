# AGV Task Scheduling MATLAB Simulator

## 1. Project Goal
本项目在固定底层导航距离下研究多 AGV **任务排序**，采用任务级离散事件时间计算。第一版只比较 FCFS 与 Random，不研究路径规划、实时避障、交通冲突、途中改派。

## 2. Original System
原系统为 C# + ProfControl，GoTo 和底层导航由 ProfControl 处理。MATLAB 是独立仿真器，不调用实时控制系统。

## 3. Exported Data
原始文件均保留不改写：stations.csv 保存站点与 Pocket membership、坐标及标记；lanes.csv 保存 PocketKey、PocketName、Sequence、StationMark、StationType；distance_matrix.csv 是 FromStation,ToStation,Distance 长表；metadata.txt 保存导出来源及语义。
站点表是每个站点/Pocket membership 一行，154 行对应 145 个唯一站点。不能把正常跨 Pocket 的重复 StationMark 当数据损坏；检查重复 membership，矩阵索引使用唯一 StationMark。
PocketKey 必须作为字符串读取，支持带 #2 等后缀；PocketName 保留前导零。

## 4. Distance Model
距离来自 ProfControl NavigationShortestPath（导航缓存或有向图 Dijkstra），不是车辆特定 GoTo 可行性。允许 D(i,j) != D(j,i)，禁止对称化。StationMark 不用作连续索引；stationMarks 与 stationToIndex 负责映射。
当前按用户要求采用 meterPerUnit=0.01，即 100 map unit = 1 m。349 unit 在 1 m/s 下为 3.49 s。**metadata 标记 MetersConversion=Unconfirmed，该比例是实验假设，需要物理校准。** 坐标也是像素，不是米。
Station 5 是孤立节点。NaN 保留原值，不补零、不补路径。loaded 路线不可达或所有 AGV 均无法空载到达时，调度不可行，makespan/fitness=invalidCost。某辆车不可达时允许选择其他可达车辆。
内部 result 距离、AGV TotalTravelDistance 单位是原始 map unit；命令行输出乘配置比例转换为米。时间一律秒。时间换算只在 getTravelTime 中进行。

## 5. Lane Model
OrderStationsDirection=DeepToEntrance；Sequence=0 是深处，数值越大越接近入口。约束只使用 StationType=Slot，取货顺序 Entrance -> Deep，Slot Sequence 降序。Entrance 和 Unknown 保留结构信息，不作为 Pickup 任务；可作为 Dropoff 站点。

## 6. Task Model
任务 table 至少含 TaskID、PickupStation、DropoffStation、ReleaseTime。示例还含 Lane（PocketKey）、Sequence、Status（初始 Pending）。算法 sequence 使用**任务行索引 1:N**，不是 TaskID 或站点号。当前所有 ReleaseTime=0，属于静态排序。
示例由真实 Slot 生成 15 个任务，配送到配置的站点 6；保证往返及初始车到 Pickup 可达，排除站点 5。这些仅为验证程序的测试任务，不代表正式实验任务。main 每次重新写 tasks/tasks_example.csv；正式任务可用 readtable 载入并替换 main 中生成任务的语句，随后调用 validateInputData。

## 7. AGV Model
每辆 AGV 保存 ID、CurrentStation、AvailableTime、TotalTravelDistance、TotalBusyTime、TaskHistory（任务行索引）。不模拟连续位置、路径节点或每秒轨迹。完成任务后停在 Dropoff。等待不计 busy time；空载、Pick、载货、Drop 均计入 busy time。利用率=busy time/makespan。

## 8. Current AGV Assignment Rule
assignAGV 对每辆车计算 start=max(predecessorReadyTime,ReleaseTime,AvailableTime)，arrival=start+emptyTravelTime；选择预计最早到达 Pickup 的车辆，并列选择配置排列中最靠前的车辆。固定分配规则不参与优化。
仿真按修复后的优先列表串行安排时间，但不同车辆时间区间可以重叠。不存在随每次派单推进的全局完成时钟；无关巷道任务可以在 t=0 开始。
当前实际车辆配置：agvIDs=[2 3 4 5]，agvInitialStations=[2 4 0 3]，依次对应 AGV02→站点2、AGV03→站点4、AGV04→站点0、AGV05→站点3。每辆车独立记录状态，但速度、Pick/Drop 时间共用配置（同质车队）。result.assignedAGV 保留内部索引1:4；result.assignedAGVID、agvs.ID 使用实际车辆编号，分配表和图表显示 AGV02 等标签。并列时按配置排列优先；当前配置按实际 ID 升序。所有关键参数集中在 config.m。

## 9. Objective Function
当前 evaluateSequence 返回 makespan，最小化 Cmax；第二输出可取得完整 result。不可行方案返回 invalidCost=1e12。后续目标扩展集中修改此接口，不能把优化算法写进模拟器。

## 10. Constraints
buildLaneConstraints(tasks,lanes) 输出 [predecessorTaskIndex,successorTaskIndex]，只在实际任务中匹配 Slot。缺少中间 Slot 时直接连接当前存在的相邻深度，例如 C -> A，不等待缺失 B。
同一深度有多个任务时，外侧深度的所有任务必须完成后才释放下一深度所有任务；同一深度不强行互相排序。共享站点的多个 Pocket 的约束取并集，环被明确报错。
repairSequence 是原排列优先级驱动的拓扑修复，保留每个任务恰好一次；重复/缺失/越界排列拒绝，约束环拒绝。checkTaskFeasible 只检查 predecessor 完成标记。
时间语义采用用户要求的**整个前置任务完成（含 Drop）**后后续任务才能开始空载行驶。它比只要求先取走外侧货物更保守；若改为 Pickup 完成释放，必须同步更新代码、验证与本 README。taskPickupFinishTime 单独记录便于后续扩展。

## 11. MATLAB Project Structure
- main.m：一键入口、种子、验证、两基线、命令行表、保存结果和图片。
- config.m：无输入返回 cfg；集中配置。
- data/loadSimulationData.m：cfg -> data，读取真实表和元数据。
- data/buildDistanceMatrix.m：stations,rows -> D,marks,mapping，检查完整有向 From-To。
- data/buildLaneConstraints.m：tasks,lanes -> 任务索引前置边。
- data/validateInputData.m：data[,tasks,cfg] -> report，检查数据、配置、任务和环。
- simulator/simulateSchedule.m：sequence,tasks,data,cfg -> result，修复、时间约束、分车、执行与统计。
- simulator/evaluateSequence.m：上述输入 -> fitness[,result]，统一优化接口。
- simulator/checkTaskFeasible.m：taskIndex,completedTasks,constraints -> logical。
- simulator/repairSequence.m：sequence,constraints -> repairedSequence，稳定优先拓扑修复。
- simulator/assignAGV.m：agvs,task,data,cfg,readyTime -> id,startTime,emptyDistance。
- simulator/getTravelDistance.m：fromStation,toStation,data -> 原始有向距离。
- simulator/getTravelTime.m：distance,cfg -> 秒，唯一距离到时间换算入口。
- algorithms/fcfsSequence.m：tasks -> 输入行顺序。
- algorithms/randomSequence.m：tasks -> randperm；仿真器统一修复。
- algorithms/algorithmTemplate.m：tasks,data,cfg -> bestSequence,bestFitness,history，基线占位接口，不是优化算法。
- tasks/generateExampleTasks.m：data,cfg -> 测试 table，并保存 tasks_example.csv。
- visualization/plotGanttChart.m：result,tasks,cfg,label -> figure，空载开始至 Drop 完成并标 TaskID。
- visualization/plotAGVUtilization.m：result,cfg,label -> figure，利用率百分比。
- visualization/printSimulationSummary.m：results,names,tasks,cfg -> 控制台摘要和分配表。
- tests/runTests.m：验证有向距离、单位、拓扑修复、并行时间、前置完成、不可达与原始文件完整性相关行为。
- results/：运行日志、MAT 结果、任务分配 CSV、前置边 CSV、两种甘特图和利用率图。

## 12. How to Run
1. 打开 MATLAB（已在 R2022a 验证，无额外工具箱要求）。
2. cd 到桌面 AGV_Simulation 文件夹。
3. 运行 main 或 run('main.m')。
运行会保留 workspace 中 cfg、data、tasks、constraints、resultFCFS、resultRandom。results/simulation_results.mat 可重新加载。图片同时显示并写出 PNG。验证测试：main 后运行 run('tests/runTests.m')。

## 13. How to Add a New Optimization Algorithm
新算法放 algorithms，仅产生完整任务行索引排列，调用 evaluateSequence，不修改仿真器。可使用如下接口：
~~~matlab
function [bestSequence,bestFitness,history] = newAlgorithm(tasks,data,cfg)
candidate = randperm(height(tasks));
[fitness,result] = evaluateSequence(candidate,tasks,data,cfg);
bestSequence = result.finalSequence;
bestFitness = fitness;
history = fitness;
end
~~~
算法专属参数也集中放配置。evaluateSequence 的修复可能让不同染色体得到同一合法序列，实验应记录修复后序列及随机种子。

## 14. Known Assumptions
静态有向最短距离；固定车速和 Pick/Drop 时间；不考虑实时路径冲突、避障、载重差异、充电、容量竞争、加减速。当前只优化任务排序，分车规则固定。共享配送站点没有容量约束。前置任务 Drop 完成后释放后续任务。

## 15. Known Data Notes
145 unique stations；154 station membership rows；34 physical pockets；21025 directed pairs；NaN count=288；Station 5 isolated（对角为零，其他进出均 NaN）。Unknown 不作为 Slot。NaN 是已知导出信息，正常运行打印统计，不需要产生 warning。

## 16. Future Work
GA、GWO、SA、ACO、禁忌搜索等；动态插单、多目标、AGV 分配联合优化、动态交通冲突。第一版不实现这些算法或交通功能。

## 17. AI Modification Guidelines
修改前先读 README；禁止对称化/删除有向距离，禁止把 Unknown 当 Slot，禁止把 StationMark 当连续下标，禁止修改原始 CSV 或擅自填 NaN。所有参数优先放 config，新算法放 algorithms，仿真器与算法解耦。改变关键假设时同步 README 与相关测试。按真实表头适配读取，保留 PocketKey 字符串及合法重复站点 membership。禁止用派单顺序替代实际完成时刻来判断前置约束。
