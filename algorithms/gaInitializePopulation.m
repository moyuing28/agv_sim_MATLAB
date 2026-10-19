function [population,attempts,complete] = gaInitializePopulation(mapping,options,stream,allowPartial)
%GAINITIALIZEPOPULATION Unique GS from randomized valid topological task orders.
n=numel(mapping.taskRows); count=options.populationSize;
if nargin<4, allowPartial=false; end
logUpper=gammaln(n+1)-sum(gammaln(mapping.counts+1));
if allowPartial
 if logUpper<log(count), count=max(1,round(exp(logUpper))); end
else
 assert(logUpper+1e-10>=log(count),'AGV:GASpace','Lane-label space is smaller than requested population.');
end
population=cell(1,0); keys=strings(1,0); attempts=0;
edges=mapping.constraints;
while numel(population)<count && attempts<options.maxInitializationAttempts
 attempts=attempts+1; done=false(1,n); ts=zeros(1,n);
 for position=1:n
  available=find(~done);
  for e=1:size(edges,1)
   if ~done(edges(e,1)), available(available==edges(e,2))=[]; end
  end
  assert(~isempty(available),'AGV:GASpace','Mapping has no topological continuation.');
  t=available(randi(stream,numel(available))); ts(position)=t; done(t)=true;
 end
 gs=encodeTS(ts,mapping); key=gsCanonicalString(gs,mapping);
 if ~any(keys==key), population{end+1}=gs; keys(end+1)=key; end %#ok<AGROW>
end
complete=numel(population)==options.populationSize;
if ~allowPartial
assert(complete,'AGV:GASpace', ...
 'Found only %d distinct legal GS after %d attempts; space may be insufficient or sampling exhausted.',numel(population),attempts);
end
end
