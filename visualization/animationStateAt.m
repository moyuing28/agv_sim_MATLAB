function state = animationStateAt(payload,time)
% Reconstruct inventory and vehicle motion at any time, including backward seeks.
base=struct('id',0,'from',0,'to',0,'ratio',0,'cargo','','status','等待','taskID',[], 'progress',0);
state.vehicles=repmat(base,numel(payload.vehicles),1);
for a=1:numel(payload.vehicles)
 v=base; v.id=payload.vehicles(a).id; latest=-Inf; latestID=0;
 v.from=payload.vehicles(a).station; v.to=v.from;
 ids=find([payload.tasks.vehicle]==v.id);
 if ~isempty(ids)
  [~,order]=sortrows([[payload.tasks(ids).start]' [payload.tasks(ids).dispatchOrder]']);
  ids=ids(order);
 end
 for t=reshape(ids,1,[])
  r=payload.tasks(t);
  if time>=r.finish, v.from=r.dropoff; v.to=v.from; latest=r.finish; latestID=r.id; continue; end
  if time<r.start, break; end
  v.taskID=r.id;
  latest=r.start; latestID=r.id;
  pickStart=r.arrivePickup; dropStart=r.arriveDropoff;
  if isfield(r,'pickupStart'), pickStart=r.pickupStart; dropStart=r.dropoffStart; end
  if time<r.arrivePickup
   v.from=r.from; v.to=r.pickup; v.ratio=(time-r.start)/(r.arrivePickup-r.start); v.status='空载行驶';
  elseif time<pickStart
   v.from=r.pickup; v.to=r.pickup; v.status='等待源巷道';
  elseif time<r.pickupFinish
   v.from=r.pickup; v.to=r.pickup; v.status='装货'; v.progress=(time-pickStart)/(r.pickupFinish-pickStart);
  elseif time<r.arriveDropoff
   v.from=r.pickup; v.to=r.dropoff; v.ratio=(time-r.pickupFinish)/(r.arriveDropoff-r.pickupFinish); v.status='载货行驶'; v.cargo=r.cargo;
  elseif time<dropStart
   v.from=r.dropoff; v.to=r.dropoff; v.status='等待目标巷道'; v.cargo=r.cargo;
  else
   v.from=r.dropoff; v.to=r.dropoff; v.status='卸货'; v.cargo=r.cargo; v.progress=(time-dropStart)/(r.finish-dropStart);
  end
  break;
 end
 if isfield(payload,'vehicleLegs')
  for leg=reshape(payload.vehicleLegs,1,[])
   if leg.vehicle~=v.id || time<leg.start || leg.start<latest || (leg.start==latest && leg.moveID<latestID), continue; end
   v.cargo=''; v.taskID=[]; v.progress=0;
   if time<leg.finish
    v.from=leg.from; v.to=leg.to; v.ratio=(time-leg.start)/(leg.finish-leg.start); v.status=leg.status;
   else
    v.from=leg.to; v.to=leg.to; v.ratio=0; v.status='等待';
   end
   latest=leg.start;
  end
 end
 state.vehicles(a)=v;
end
state.cargo=payload.cargo;
for c=1:numel(state.cargo)
 state.cargo(c).onboard=false;
 ids=find(strcmp({payload.tasks.cargo},state.cargo(c).id) & [payload.tasks.vehicle]~=0);
 if isempty(ids), continue; end
 [~,order]=sort([payload.tasks(ids).start]);
 for t=reshape(ids(order),1,[])
  r=payload.tasks(t);
  if time>=r.finish
   state.cargo(c).station=r.dropoff;
  elseif time>=r.pickupFinish
   state.cargo(c).onboard=true; break;
  else
   break;
  end
 end
end
assigned=[payload.tasks.vehicle]~=0;
state.completed=sum(time>=[payload.tasks(assigned).finish]);
if isfield(payload,'customerCompletionTimes')
 state.customerCompleted=sum(time>=payload.customerCompletionTimes);
end
end
