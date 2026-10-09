# MATLAB 实际运行验收报告

运行环境：MATLAB R2022a；2026-10-08。main.m 已成功运行，所有调度 invariant 测试通过，退出码 0。运行输出无 warning/error。原始四个数据文件 SHA-256 核对无变化（results/source_hashes.json）。

## 数据及建模验收
- 145 个唯一站点，154 条站点/Pocket membership。
- 34 个 Pocket，21025 条有向距离，288 个 NaN。
- Station 5 孤立已正确识别；有向不对称值保留。
- 15 个示例任务，4 辆 AGV，9 条前置边。
- README 17 节完整生成；算法与仿真模块解耦。
- 固定 earliest pickup arrival 分车；前置任务 Drop 完成后后续任务才能开始。
- 两张甘特图与两张利用率图成功生成并人工视觉检查。
- 单位换算 0.01 m/unit 是用户指定假设，元数据仍标未校准。
- AGV 初始站点 [6 6 6 6] 需按正式实验修改。

## 结果
|算法|Makespan / s|Total distance / m|
|---|---:|---:|
|FCFS|568.54|1190.72|
|Random（seed=1）|568.54|1190.72|

FCFS 修复后任务优先顺序：7 6 5 4 3 2 1 9 8 10 12 11 13 15 14。
Random 修复后任务优先顺序：15 7 6 5 13 4 3 9 8 10 12 11 2 1 14。
这里的顺序是调度优先列表；多车实际开始/完成时间可以交错。
两基线工期相同：长巷道任务链 T7 -> T6 -> T5 -> T4 -> T3 -> T2 -> T1 决定总工期；示例只用于正确性验证，不能据此断言算法性能相同。

## 任务分配
|TaskID|Pickup|Dropoff|FCFS AGV|Random AGV|
|---:|---:|---:|---:|---:|
|1|85|6|1|1|
|2|63|6|1|1|
|3|16|6|1|1|
|4|139|6|1|1|
|5|134|6|1|1|
|6|129|6|1|2|
|7|12|6|1|2|
|8|8|6|2|4|
|9|32|6|2|4|
|10|10|6|3|2|
|11|19|6|4|3|
|12|15|6|4|3|
|13|21|6|3|3|
|14|25|6|2|4|
|15|24|6|2|1|

各任务 StartTime、FinishTime 详见 results/fcfs_tasks.csv 和 results/random_tasks.csv。完整 MATLAB 输出保存在 results/matlab_verified.log；MAT 结果保存在 results/simulation_results.mat。

## 验证范围
实际数据规模、孤立节点、距离方向性、单位换算；稳定拓扑修复、重复/缺失任务与环；缺失中间 Slot 不阻塞；前置完成时间；AGV 不重叠；独立任务并行开始；busy time 和利用率；loaded/empty 不可达返回 invalidCost。

## 目录和文件清单
原始保留文件：stations.csv、lanes.csv、distance_matrix.csv、metadata.txt。
新建文件及输出如下：
~~~text
algorithms/algorithmTemplate.m
algorithms/fcfsSequence.m
algorithms/randomSequence.m
config.m
data/buildDistanceMatrix.m
data/buildLaneConstraints.m
data/loadSimulationData.m
data/validateInputData.m
main.m
README.md
results/fcfs_gantt.png
results/fcfs_tasks.csv
results/fcfs_utilization.png
results/matlab_verified.log
results/precedence_constraints.csv
results/random_gantt.png
results/random_tasks.csv
results/random_utilization.png
results/run_log.txt
results/simulation_results.mat
results/source_hashes.json
simulator/assignAGV.m
simulator/checkTaskFeasible.m
simulator/evaluateSequence.m
simulator/getTravelDistance.m
simulator/getTravelTime.m
simulator/repairSequence.m
simulator/simulateSchedule.m
tasks/generateExampleTasks.m
tasks/tasks_example.csv
tests/runTests.m
visualization/plotAGVUtilization.m
visualization/plotGanttChart.m
visualization/printSimulationSummary.m
results/acceptance_report.md
~~~

## 一键运行
~~~matlab
cd('C:/Users/huhan/Desktop/AGV_Simulation')
main
~~~
测试可单独运行 run('tests/runTests.m')。参数在 config.m 中调整。正式实验前请校准单位和设置初始站点、正式任务集。
