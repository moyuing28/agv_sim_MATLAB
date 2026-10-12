function outputFile = exportScheduleAnimation(result,tasks,data,cfg,label,outputFile)
% Export a schematic replay; interpolation does not change simulation events.
% Failed schedules replay only dispatched work and show the blocking reason.
assert(isfield(result,'taskTable'),'AGV:Animation','Schedule has no replay data.');
if nargin<6
 outputFile=fullfile(cfg.resultsDir,[lower(char(label)) '_animation.html']);
end
payload=buildAnimationData(result,tasks,data,cfg,label);
template=fileread(fullfile(fileparts(mfilename('fullpath')),'scheduleAnimation.html'));
json=jsonencode(payload);
% Keep input text inside application/json, even if an ID contains HTML markup.
json=strrep(json,'<','\u003c'); json=strrep(json,'>','\u003e'); json=strrep(json,'&','\u0026');
html=strrep(template,'__SCHEDULE_DATA__',json);
fid=fopen(outputFile,'w','n','UTF-8');
assert(fid>=0,'AGV:AnimationFile','Cannot write animation: %s',outputFile);
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',html);
fprintf('Animation: %s\n',outputFile);
end
