function outputFile = exportScheduleGIF(result,tasks,data,cfg,label,outputFile)
% Render a self-contained, looping GIF for slides, using the HTML replay data.
assert(isfield(result,'taskTable'),'AGV:Animation','Schedule has no replay data.');
if nargin<6, outputFile=fullfile(cfg.resultsDir,[lower(char(label)) '_animation.gif']); end
assert(isfinite(cfg.gifFPS) && cfg.gifFPS>=1 && cfg.gifFPS<=50,'AGV:GIFConfig','gifFPS must be between 1 and 50.');
assert(isfinite(cfg.gifMaxDuration) && cfg.gifMaxDuration>0,'AGV:GIFConfig','gifMaxDuration must be positive.');
assert(numel(cfg.gifResolution)==2 && all(cfg.gifResolution>=320),'AGV:GIFConfig','gifResolution must contain width and height (at least 320).');
assert(isfinite(cfg.animationSpeed) && cfg.animationSpeed>0,'AGV:GIFConfig','animationSpeed must be positive.');
p=buildAnimationData(result,tasks,data,cfg,label);
motionSeconds=min(cfg.gifMaxDuration,p.duration/cfg.animationSpeed);
frameCount=max(2,ceil(motionSeconds*cfg.gifFPS)+1);
times=linspace(0,p.duration,frameCount);
% Include event boundaries so short/zero-length phases and final inventory are exact.
if p.duration>0
 assigned=[p.tasks.vehicle]~=0;
 events=unique([p.tasks(assigned).start p.tasks(assigned).arrivePickup p.tasks(assigned).pickupFinish p.tasks(assigned).arriveDropoff p.tasks(assigned).finish]);
 if isfield(p,'vehicleLegs'), events=unique([events p.vehicleLegs.start p.vehicleLegs.finish]); end
 for e=events
  [~,idx]=min(abs(times-e));
  if idx>1 && idx<frameCount, times(idx)=e; end
 end
 times=unique(times);
else
 times=0;
end
delay=round(100/cfg.gifFPS)/100;
stations=p.stations;
if ~cfg.gifShowAllStations
 relevant=unique([[p.vehicles.station] [p.tasks.pickup] [p.tasks.dropoff]]);
 stations=stations(ismember([stations.id],relevant));
end
marks=[stations.id];
groups=unique(string({stations.pocket}),'stable');
cols=max(1,min(6,ceil(sqrt(numel(groups))))); rows=ceil(numel(groups)/cols);
pos=zeros(numel(stations),2);
rowWeights=zeros(1,rows);
for row=1:rows
 groupIDs=(row-1)*cols+1:min(row*cols,numel(groups));
 counts=arrayfun(@(g)sum(strcmp({stations.pocket},groups(g))),groupIDs);
 rowWeights(row)=max(counts)+1.8;
end
unit=86/max(1,sum(rowWeights));
for row=1:rows
 groupIDs=(row-1)*cols+1:min(row*cols,numel(groups));
 for col=1:numel(groupIDs)
  ids=find(strcmp({stations.pocket},groups(groupIDs(col))));
  [~,order]=sort([stations(ids).sequence]); ids=ids(order);
  x=8+(col-1)*88/cols;
  yTop=91-sum(rowWeights(1:row-1))*unit;
  spacing=min(12,unit);
  pos(ids,:)=[repmat(x,numel(ids),1) (yTop-(0:numel(ids)-1)*spacing)'];
 end
end
fig=figure('Visible','off','Color',[.941 .957 .980],'Position',[100 100 cfg.gifResolution], ...
 'Name',['GIF export - ' char(label)],'Renderer','opengl','InvertHardcopy','off');
set(fig,'PaperUnits','inches','PaperPosition',[0 0 cfg.gifResolution/100], ...
 'PaperSize',cfg.gifResolution/100,'PaperPositionMode','manual');
cleanup=onCleanup(@()close(fig));
annotation(fig,'textbox',[.03 .92 .94 .065],'String',[char(label) '  ·  AGV 任务时序动画'], ...
 'EdgeColor','none','FontName','Microsoft YaHei','FontSize',20,'FontWeight','bold','Interpreter','none');
ax=axes(fig,'Position',[.035 .24 .7 .65]); hold(ax,'on'); axis(ax,[0 100 0 100]); axis(ax,'off');
rectangle(ax,'Position',[0 0 100 100],'FaceColor',[.973 .980 1],'EdgeColor',[.86 .90 .95],'Curvature',.02);
annotation(fig,'rectangle',[.755 .23 .225 .66],'FaceColor','white','Color',[.86 .90 .95]);
annotation(fig,'rectangle',[.025 .025 .955 .145],'FaceColor','none','Color',[.86 .90 .95]);
colors=[51 107 228;21 155 131;152 89 209;220 101 112;187 123 33;69 126 141]/255;
colors=colors(mod(0:max(0,numel(p.vehicles)-1),size(colors,1))+1,:);
routeLines=gobjects(0); routeTasks=[]; routeEmpty=[];
stationSize=min(20,max(7,.65*cfg.gifResolution(2)/100*min(12,unit)*.72*.82));
labelSize=min(8,max(6,stationSize*.5));
for t=1:numel(p.tasks)
 r=p.tasks(t); a=find([p.vehicles.id]==r.vehicle,1);
 if isempty(a), routeColor=[.7 .73 .79]; else, routeColor=colors(a,:)*.45+.55; end
 pairs=[r.pickup r.dropoff];
 if r.vehicle, pairs=[r.from r.pickup;pairs]; end
 for j=1:size(pairs,1)
  [~,indices]=ismember(pairs(j,:),marks); xy=pos(indices,:);
  empty=r.vehicle && j==1;
  if empty||~r.vehicle, style='--'; else, style='-'; end
  routeLines(end+1)=plot(ax,xy(:,1),xy(:,2),style,'Color',routeColor,'LineWidth',1); %#ok<AGROW>
  routeTasks(end+1)=t; routeEmpty(end+1)=empty; %#ok<AGROW>
 end
end
for g=1:numel(groups)
 ids=find(strcmp({stations.pocket},groups(g)));
 xy=pos(ids,:); name=['巷道 ' char(groups(g))];
 if groups(g)=="AGV start", name='初始站点'; end
 text(ax,xy(1,1)-4,max(xy(:,2))+5,name,'FontName','Microsoft YaHei','FontSize',9,'Color',[.4 .47 .56],'Interpreter','none');
end
for s=1:numel(stations)
 plot(ax,pos(s,1),pos(s,2),'o','MarkerSize',stationSize,'MarkerFaceColor','white','MarkerEdgeColor',[.62 .69 .79]);
 text(ax,pos(s,1),pos(s,2),num2str(stations(s).id),'HorizontalAlignment','center','FontSize',labelSize);
end
cargoIcons=gobjects(numel(p.cargo),1); cargoLabels=gobjects(numel(p.cargo),1);
for c=1:numel(p.cargo)
 cargoIcons(c)=plot(ax,NaN,NaN,'s','MarkerSize',min(10,stationSize*.7),'MarkerFaceColor',[.97 .7 .25],'MarkerEdgeColor',[.74 .5 .12]);
 cargoLabels(c)=text(ax,0,0,p.cargo(c).id,'FontSize',labelSize,'Color',[.55 .35 .1],'Interpreter','none','Visible','off');
end
vehicleIcons=gobjects(numel(p.vehicles),1); vehicleLabels=vehicleIcons; loadIcons=vehicleIcons; loadLabels=vehicleIcons; statusLabels=vehicleIcons; vehicleNumbers=vehicleIcons;
wheelIcons=gobjects(numel(p.vehicles),4);
carWidth=100/(.7*cfg.gifResolution(1))*34;
carHeight=100/(.65*cfg.gifResolution(2))*22;
for a=1:numel(p.vehicles)
 for wheel=1:4
  wheelIcons(a,wheel)=rectangle(ax,'Position',[0 0 carWidth*.19 carHeight*.16],'FaceColor',[.15 .22 .32],'EdgeColor','none');
 end
 vehicleIcons(a)=rectangle(ax,'Position',[0 0 carWidth carHeight],'Curvature',.5,'FaceColor',colors(a,:),'EdgeColor','white','LineWidth',1.5);
 vehicleNumbers(a)=text(ax,0,0,sprintf('%02d',p.vehicles(a).id),'FontSize',8,'FontWeight','bold','Color','white','HorizontalAlignment','center');
 vehicleLabels(a)=text(ax,0,0,sprintf('AGV%02d',p.vehicles(a).id),'FontSize',8,'Color',colors(a,:),'HorizontalAlignment','center');
 loadIcons(a)=plot(ax,NaN,NaN,'s','MarkerSize',10,'MarkerFaceColor',[.97 .7 .25],'MarkerEdgeColor',[.74 .5 .12]);
 loadLabels(a)=text(ax,0,0,'','FontSize',8,'Color',[.55 .35 .1],'Interpreter','none');
 cardY=.69-(a-1)*min(.115,.48/max(1,numel(p.vehicles)));
 cardHeight=min(.11,.48/max(1,numel(p.vehicles)));
 annotation(fig,'rectangle',[.765 cardY .205 cardHeight],'Color',[.9 .93 .97]);
 statusLabels(a)=annotation(fig,'textbox',[.77 cardY+.008 .2 cardHeight-.016], ...
  'String','','EdgeColor','none','FontName','Microsoft YaHei','FontSize',11,'Color',colors(a,:),'Interpreter','none');
end
timeLabel=annotation(fig,'textbox',[.765 .82 .22 .07],'String','','EdgeColor','none','FontSize',15,'FontWeight','bold','Interpreter','none');
legendText='圆圈：站点   彩色方块：AGV   黄色方块：货物';
if cfg.gifShowAllStations, scope='全部货位'; else, scope='仅任务相关站点'; end
annotation(fig,'textbox',[.035 .17 .93 .05],'String',[legendText '  |  ' scope '  |  示意连线，非真实导航路径'], ...
 'EdgeColor','none','FontName','Microsoft YaHei','FontSize',10,'Color',[.4 .47 .56],'Interpreter','none');
if ~p.feasible
 annotation(fig,'textbox',[.765 .24 .22 .12],'String',['调度受阻：' p.reason],'EdgeColor','none','FontName','Microsoft YaHei','FontSize',9,'Color',[.65 .35 .08],'Interpreter','none');
end
timeline=axes(fig,'Position',[.1 .06 .85 .095]); hold(timeline,'on');
set(timeline,'Color','white');
for t=1:numel(p.tasks)
 r=p.tasks(t); if ~r.vehicle, continue; end
 a=find([p.vehicles.id]==r.vehicle,1); edges=[r.start r.arrivePickup r.pickupFinish r.arriveDropoff r.finish];
 fills=[.7 .75 .83;.97 .7 .25;colors(a,:);.97 .7 .25];
 for j=1:4
  if edges(j+1)>edges(j), rectangle(timeline,'Position',[edges(j) a-.3 edges(j+1)-edges(j) .6],'FaceColor',fills(j,:),'EdgeColor','none'); end
 end
end
xlim(timeline,[0 max(1,p.duration)]); ylim(timeline,[.5 numel(p.vehicles)+.5]);
set(timeline,'YTick',1:numel(p.vehicles),'YTickLabel',compose('AGV%02d',[p.vehicles.id]),'FontSize',8,'Box','off');
xlabel(timeline,'仿真时间 / s','FontName','Microsoft YaHei');
cursor=plot(timeline,[0 0],[.5 numel(p.vehicles)+.5],'-','Color',[.89 .25 .28],'LineWidth',2);
% Write to a temporary file so a failed export cannot replace a valid previous GIF.
tempFile=[tempname(fileparts(outputFile)) '.gif'];
tempCleanup=onCleanup(@()deleteIfExists(tempFile));
for frame=1:numel(times)
 now=times(frame); state=animationStateAt(p,now);
 set(timeLabel,'String',sprintf('%.2f / %.2f s\n完成 %d / %d',now,p.duration,state.completed,numel(p.tasks)));
 set(cursor,'XData',[now now]);
 for c=1:numel(state.cargo)
  cargo=state.cargo(c); index=find(marks==cargo.station,1);
  visible=~cargo.onboard && ~isempty(index);
  if visible
   set(cargoIcons(c),'XData',pos(index,1)+3,'YData',pos(index,2)+.5,'Visible','on');
   set(cargoLabels(c),'Position',[pos(index,1)+4.5 pos(index,2) 0],'Visible','on');
  else, set(cargoIcons(c),'Visible','off'); set(cargoLabels(c),'Visible','off'); end
 end
 for a=1:numel(state.vehicles)
  v=state.vehicles(a); [~,indices]=ismember([v.from v.to],marks);
  xy=pos(indices(1),:)+(pos(indices(2),:)-pos(indices(1),:))*v.ratio;
  peers=find([state.vehicles.from]==v.from & [state.vehicles.to]==v.to & [state.vehicles.ratio]==v.ratio);
  xy=xy+[-2.5-3*(find(peers==a)-1) 0];
  set(vehicleIcons(a),'Position',[xy(1)-carWidth/2 xy(2)-carHeight/2 carWidth carHeight]);
  set(vehicleNumbers(a),'Position',[xy(1) xy(2) 0]);
  for wheel=1:4
   sx=mod(wheel-1,2)*2-1; sy=floor((wheel-1)/2)*2-1;
   set(wheelIcons(a,wheel),'Position',[xy(1)+sx*carWidth*.3-carWidth*.095 xy(2)+sy*carHeight*.5-carHeight*.08 carWidth*.19 carHeight*.16]);
  end
  set(vehicleLabels(a),'Position',[xy(1) xy(2)-3.5 0]);
  if cfg.gifShowAllStations || stationSize<16
   set(vehicleLabels(a),'Position',[xy(1)-2 xy(2) 0],'HorizontalAlignment','right','FontSize',labelSize);
  end
  if isempty(v.cargo), set(loadIcons(a),'Visible','off'); set(loadLabels(a),'Visible','off');
  else
   set(loadIcons(a),'XData',xy(1),'YData',xy(2)+3.5,'Visible','on');
   set(loadLabels(a),'Position',[xy(1)-1.2 xy(2)+3.5 0],'HorizontalAlignment','right','String',v.cargo,'Visible','on');
  end
  task=''; if ~isempty(v.taskID), task=sprintf(' · T%g',v.taskID); end
  cargo=v.cargo; if isempty(cargo), cargo='空载'; end
  service=''; if ismember(string(v.status),["装货" "卸货"]), service=sprintf(' %.0f%%',v.progress*100); end
  set(statusLabels(a),'String',sprintf('AGV%02d  %s%s%s\n%g → %g  |  %s',v.id,v.status,task,service,v.from,v.to,cargo));
 end
 for l=1:numel(routeLines)
  r=p.tasks(routeTasks(l)); active=false;
  if r.vehicle
   if routeEmpty(l), active=now>=r.start && now<r.arrivePickup;
   else, active=now>=r.pickupFinish && now<r.arriveDropoff; end
   a=find([p.vehicles.id]==r.vehicle,1);
   if active, set(routeLines(l),'Color',colors(a,:),'LineWidth',2.5);
   else, set(routeLines(l),'Color',colors(a,:)*.45+.55,'LineWidth',1); end
  end
 end
 drawnow;
 % Off-screen print avoids graphics-driver capture issues and normalizes DPI.
 rgb=print(fig,'-RGBImage','-r100');
 [indexed,map]=rgb2ind(rgb,256,'nodither');
 frameDelay=delay; if frame==1, frameDelay=1; end
 if frame==numel(times), frameDelay=2; end
 if frame==1, imwrite(indexed,map,tempFile,'gif','LoopCount',Inf,'DelayTime',frameDelay);
 else, imwrite(indexed,map,tempFile,'gif','WriteMode','append','DelayTime',frameDelay); end
end
[ok,msg]=movefile(tempFile,outputFile,'f'); assert(ok,'AGV:GIFFile','Cannot save GIF: %s',msg);
fprintf('GIF animation: %s (%d frames)\n',outputFile,numel(times));
end

function deleteIfExists(path)
if isfile(path), delete(path); end
end
