% Function: plotGanttChart
% Purpose: Draw task start-finish intervals on AGV rows.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function fig = plotGanttChart(result,tasks,cfg,label)
assert(result.isFeasible,'AGV:Plot','Cannot plot infeasible schedule.');
fig=figure('Name',['Gantt - ' label]); hold on; colors=lines(max(1,height(tasks)));
for t=1:height(tasks)
 a=result.assignedAGV(t); start=result.taskStartTime(t); duration=result.taskFinishTime(t)-start;
 rectangle('Position',[start a-0.35 duration 0.7],'FaceColor',colors(t,:),'EdgeColor','k');
 text(start+duration/2,a,sprintf('T%g',tasks.TaskID(t)),'HorizontalAlignment','center','FontSize',8);
end
yticks(1:cfg.numAGV); yticklabels(compose('AGV%02d',cfg.agvIDs)); ylim([0.5 cfg.numAGV+0.5]);
xlabel('Time / s'); ylabel('AGV'); title(['Task schedule - ' label]); grid on;
end
