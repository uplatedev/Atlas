// Offline algebra proof only. No Godot, queries, iterative search or production imports.
// Coordinate order: [body-forward, world-up], positive pitch raises the toes.
import fs from 'node:fs';
const rad=d=>d*Math.PI/180, degrees=r=>r*180/Math.PI;
const add=(a,b)=>a.map((v,i)=>v+b[i]);
const sub=(a,b)=>a.map((v,i)=>v-b[i]);
const mul=(a,k)=>a.map(v=>v*k);
const dot=(a,b)=>a.reduce((sum,v,i)=>sum+v*b[i],0);
const len=a=>Math.hypot(...a), clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
const rot=(v,p)=>[v[0]*Math.cos(p)-v[1]*Math.sin(p),v[0]*Math.sin(p)+v[1]*Math.cos(p)];
const angle=(a,b)=>Math.acos(clamp(dot(a,b)/(len(a)*len(b)),-1,1));
const distance=(a,b)=>len(sub(a,b));
const bodies=[
 {name:'Artemis',upper:.334537,lower:.339238,ankleHeight:.097054,toeReach:Math.hypot(.009045,.088827)},
 {name:'Gemiddeld',upper:.38,lower:.38,ankleHeight:.11,toeReach:.14},
 {name:'Lange bovenbenen',upper:.49,lower:.32,ankleHeight:.11,toeReach:.14},
 {name:'Korte bovenbenen',upper:.27,lower:.44,ankleHeight:.11,toeReach:.14}
];
function twoBone(hip,goal,a,b) {
 const v=sub(goal,hip),d=len(v),axis=mul(v,1/d);
 // Project forward knee pole [1,0] off hip-goal axis, same branch as game solver.
 const pole=sub([1,0],mul(axis,axis[0]));
 const bend=mul(pole,1/len(pole));
 const along=(a*a-b*b+d*d)/(2*d);
 return add(hip,add(mul(axis,along),mul(bend,Math.sqrt(Math.max(0,a*a-along*along)))));
}
function solve(body,hip,forefoot,q,kneeMin=rad(5),kneeMax=rad(155)) {
 const a=body.upper,b=body.lower,r=[body.toeReach,-body.ankleHeight];
 // K->A is (0,-b) in the neutral shin frame. Both vectors share rotation -shin_tilt.
 const w=add([0,-b],rot(r,q)),effective=len(w),offset=Math.atan2(w[0],-w[1]);
 // Actual knee flex = effective knee flex + offset on the forward-pole branch.
 const minEffective=Math.max(0,kneeMin-offset),maxEffective=Math.min(Math.PI,kneeMax-offset);
 if (maxEffective<minEffective) return {ok:false,reason:'no valid forward knee branch'};
 const dMin=Math.sqrt(Math.max(0,a*a+effective*effective+2*a*effective*Math.cos(maxEffective)));
 const dMax=Math.sqrt(Math.max(0,a*a+effective*effective+2*a*effective*Math.cos(minEffective)));
 const d=distance(hip,forefoot);
 // Never move a proven world contact to hide an unreachable target.
 if(d<dMin-1e-10 || d>dMax+1e-10 || d<1e-9) return {ok:false,reason:'outside contact reach',d,dMin,dMax};
 const knee=twoBone(hip,forefoot,a,effective);
 const ankle=add(knee,mul(rot(sub(forefoot,knee),-offset),b/effective));
 const shin=sub(knee,ankle),shinTilt=Math.atan2(shin[0],shin[1]);
 const pitch=q-shinTilt;
 const toe=add(ankle,rot(r,pitch));
 const heel=add(ankle,rot([-body.toeReach*.25,-body.ankleHeight],pitch));
 const actualFlex=angle(sub(knee,hip),sub(ankle,knee));
 const reconstructedKnee=twoBone(hip,ankle,a,b);
 return {ok:true,knee,ankle,pitch,actualFlex,offset,toe,heel,
  upperError:Math.abs(distance(hip,knee)-a),lowerError:Math.abs(distance(knee,ankle)-b),
  contactError:distance(toe,forefoot),ordinarySolverKneeError:distance(knee,reconstructedKnee),
  ankleAngleError:Math.abs((pitch+shinTilt)-q),
  kneeValid:actualFlex>=kneeMin-1e-9&&actualFlex<=kneeMax+1e-9,
  forefootFirst:heel[1]>=forefoot[1]-1e-9};
}
const report={scope:'Sagittal offline contact algebra; not a Godot/mesh/world-contact proof',
 parameters:'Exact existing limb lengths and current central sole-marker approximation; goals are normalized synthetic geometry',
 algebra:'w=(0,-b)+R(q)*(toeReach,-ankleHeight); beta=atan2(w.forward,-w.up); B=|w|; effective knee limits=clamp(real limits-beta,0,pi); solve H-K-C lengths a,B; A=K+(b/B)*R(-beta)*(C-K); p=q-atan2((K-A).forward,(K-A).up)',
 bodies:[],examples:[],maxError:0,failures:[]};
for(const body of bodies){
 const L=body.upper+body.lower;
 const result={name:body.name,solved:0,unreachable:0,notForefootFirst:0,maxUpperError:0,maxLowerError:0,maxContactError:0,maxOrdinarySolverKneeError:0,maxAnkleAngleError:0,kneeMinDegrees:180,kneeMaxDegrees:0};
 for(const qdeg of [-45,-20,0,10,20]) for(const height of [.55,.65,.75,.85,.95,1.0]) for(const back of [.05,.15,.25,.35,.45,.55]) for(const clearance of [0,.03]) for(const limits of [[5,155],[15,100]]) {
  const H=[0,body.ankleHeight+height*L],C=[-back*L,clearance*L],q=rad(qdeg);
  const s=solve(body,H,C,q,rad(limits[0]),rad(limits[1]));
  if(!s.ok){result.unreachable++;continue;}
  result.solved++;
  if(!s.forefootFirst)result.notForefootFirst++;
  for(const [key,out] of [['upperError','maxUpperError'],['lowerError','maxLowerError'],['contactError','maxContactError'],['ordinarySolverKneeError','maxOrdinarySolverKneeError'],['ankleAngleError','maxAnkleAngleError']])result[out]=Math.max(result[out],s[key]);
  result.kneeMinDegrees=Math.min(result.kneeMinDegrees,degrees(s.actualFlex));
  result.kneeMaxDegrees=Math.max(result.kneeMaxDegrees,degrees(s.actualFlex));
  if(!s.kneeValid)report.failures.push(`${body.name}: actual knee outside requested limits`);
 }
 report.maxError=Math.max(report.maxError,result.maxUpperError,result.maxLowerError,result.maxContactError,result.maxOrdinarySolverKneeError,result.maxAnkleAngleError);
 report.bodies.push(result);
 const H=[0,body.ankleHeight+.80*L],C=[-.30*L,0],s=solve(body,H,C,rad(20));
 report.examples.push({name:body.name,hip:H,forefoot:C,...s,pitchDegrees:s.ok?degrees(s.pitch):null,kneeDegrees:s.ok?degrees(s.actualFlex):null});
}
// q=20 is the existing upper ankle limit, not a newly relaxed limit.
// Capture-inspired numbers below omit actual root flight/lean/pelvis offsets.
// They demonstrate the feedback problem and algebra; they do NOT reproduce the engine trace.
const body=bodies[1],H=[0,.87-.163013],oldA=[-.319523,.172438-.0456];
const oldK=twoBone(H,oldA,body.upper,body.lower);
const oldShin=sub(oldK,oldA),oldPitch=rad(20)-Math.atan2(oldShin[0],oldShin[1]);
const oldToe=add(oldA,rot([body.toeReach,-body.ankleHeight],oldPitch));
const repair=solve(body,H,[oldToe[0],0],rad(20));
report.illustration={explicitlyApproximate:true,oldAnkle:oldA,oldToe,oldPitchDegrees:degrees(oldPitch),repairedAnkle:repair.ankle,repairedToe:repair.toe,repairedPitchDegrees:degrees(repair.pitch),actualKneeDegrees:degrees(repair.actualFlex)};
if(report.maxError>1e-8)report.failures.push('algebra residual exceeded 1e-8');
if (process.argv[2]) fs.writeFileSync(process.argv[2], JSON.stringify(report,null,2));
console.log(JSON.stringify({maxError:report.maxError,bodies:report.bodies,examples:report.examples.map(x=>({name:x.name,ok:x.ok,ankle:x.ankle,pitch:x.pitchDegrees,knee:x.kneeDegrees,heel:x.heel,forefootFirst:x.forefootFirst})),illustration:report.illustration,failures:report.failures},null,2));
process.exitCode=report.failures.length?1:0;