function state = animationStateAt(payload,time)
% Reconstruct inventory and vehicle motion at any time, including backward seeks.
base=struct('id',0,'from',0,'to',0,'ratio',0,'cargo','','status','等待','taskID',[], 'progress',0);
state.vehicles=repmat(base,numel(payload.vehicles),1);
for a=1:numel(payload.vehicles)
 v=base; v.id=payload.vehicles(a).id;
 v.from=payload.vehicles(a).station; v.to=v.from;
 ids=find([payload.tasks.vehicle]==v.id);
 if ~isempty(ids)
  [~,order]=sortrows([[payload.tasks(ids).start]' [payload.tasks(ids).dispatchOrder]']);
  ids=ids(order);
 end
 for t=reshape(ids,1,[])
  r=payload.tasks(t);
  if time>=r.finish, v.from=r.dropoff; v.to=v.from; continue; end
  if time<r.start, break; end
  v.taskID=r.id;
  if time<r.arrivePickup
   v.from=r.from; v.to=r.pickup; v.ratio=(time-r.start)/(r.arrivePickup-r.start); v.status='空载行驶';
  elseif time<r.pickupFinish
   v.from=r.pickup; v.to=r.pickup; v.status='装货'; v.progress=(time-r.arrivePickup)/(r.pickupFinish-r.arrivePickup);
  elseif time<r.arriveDropoff
   v.from=r.pickup; v.to=r.dropoff; v.ratio=(time-r.pickupFinish)/(r.arriveDropoff-r.pickupFinish); v.status='载货行驶'; v.cargo=r.cargo;
  else
   v.from=r.dropoff; v.to=r.dropoff; v.status='卸货'; v.cargo=r.cargo; v.progress=(time-r.arriveDropoff)/(r.finish-r.arriveDropoff);
  end
  break;
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
end
