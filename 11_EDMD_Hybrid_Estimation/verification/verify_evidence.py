"""Independently audit stored evidence for the project's current frozen study.

This recomputes CSV arithmetic and checks metadata/hashes; it does not run
MATLAB, refit models, validate hardware, or confer an EDMD benefit verdict.
See verification/README.md for the fixed coverage and interpretation limits.
"""
import argparse
import csv, json, math, hashlib
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path
from collections import defaultdict
import numpy as np

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--project-root',type=Path,default=Path(__file__).resolve().parent.parent,
                    help='Project folder (default: parent of this verification folder).')
parser.add_argument('--output',type=Path,
                    help='Optional JSON result path; the complete result is also printed.')
args=parser.parse_args()
ROOT=args.project_root.expanduser().resolve()
OUT=args.output.expanduser().resolve() if args.output else None
ABSOLUTE_TOLERANCE=1e-11
RELATIVE_TOLERANCE=1e-10
result={
    'schema':'edmd-independent-stored-evidence-audit-v1',
    'scope':'Current frozen 24 training / 12 validation / 40 original test / 52 correction test study. Independent stored CSV arithmetic, metadata, and historical hash audit only; no MATLAB execution, physical-data uniqueness check, bootstrap interval reproduction, or hardware/EMI/closed-loop/incremental-EDMD certification.',
    'projectRoot':str(ROOT),
    'environment':{'pythonVersion':platform.python_version(),'pythonExecutable':sys.executable,'numpyVersion':np.__version__},
    'numericTolerance':{'absolute':ABSOLUTE_TOLERANCE,'relative':RELATIVE_TOLERANCE,
                        'rule':'abs(actual - expected) <= absolute + relative * abs(expected)',
                        'note':'Allows CSV decimal rounding. Overall maximum includes differently scaled diagnostics such as condition numbers; per-study maxima describe forecast/event scoring differences.'},
}; checks=0; maxdiff=0.
def check(cond,msg):
    global checks
    checks+=1
    if not cond: raise AssertionError(msg)
def close(a,b,msg):
    global maxdiff
    a=float(a);b=float(b)
    if math.isnan(a) and math.isnan(b): return
    if math.isinf(a) or math.isinf(b): check(a==b,msg); return
    d=abs(a-b);maxdiff=max(maxdiff,d)
    check(d<=ABSOLUTE_TOLERANCE+RELATIVE_TOLERANCE*abs(b), f'{msg}: {a} vs {b}, delta {d}')
def rows(file):
    with file.open(encoding='utf-8-sig', newline='') as f:return list(csv.DictReader(f))
def f(row,key):return float(row[key])
def key(row):return (row['modelName'],row['regime'],int(row['runIndex']),int(row['horizonSamples']))
def skey(row):return (row['modelName'],row['regime'],int(row['horizonSamples']))
def metrics(e):
    out={}
    for a,b in [('truthError','truth'),('measurementError','measurement')]:
        x=np.array([f(z,a) for z in e]); n=len(x)
        out[b+'Bias']=np.mean(x);out[b+'Std']=np.std(x)
        out[b+'RMSE']=np.sqrt(np.mean(x*x))
        out[b+'P95AbsoluteError']=np.sort(abs(x))[math.ceil(.95*n)-1]
        out[b+'MaxAbsoluteError']=max(abs(x))
    x=np.array([f(z,'posteriorTruthError') for z in e]);out['posteriorTruthRMSE']=np.sqrt(np.mean(x*x))
    out['forecastCount']=len(e);out['nonfiniteForecastCount']=sum(int(z['nonfinite']) for z in e)
    out['learnedCandidateNonfiniteCount']=sum(int(z['learnedCandidateNonfinite']) for z in e)
    out['unknownReversalForecastCount']=sum(1-int(z['reversalLabelAvailable']) for z in e)
    out['startupTargetCount']=sum(int(z['targetInStartup']) for z in e)
    return out
def audit_run(folder,pairedname,expected):
    global maxdiff
    e=rows(folder/'forecast_endpoints.csv');pr=rows(folder/'forecast_per_run.csv');s=rows(folder/'forecast_summary.csv')
    er=rows(folder/'event_per_run.csv');es=rows(folder/'event_summary.csv');pairs=rows(folder/pairedname)
    check(len(e)==expected,'endpoint count')
    groups=defaultdict(list);seen=set(); decisions={}; origins={}; eventgroups={};eventmetrics={}
    for z in e:
        k=key(z);o=int(z['originIndex']);h=k[-1];pk=k+(o,)
        check(pk not in seen,'duplicate endpoint');seen.add(pk);groups[k].append(z)
        check(int(z['targetIndex'])==o+h,'target index')
        close(f(z,'targetTimeSeconds')-f(z,'originTimeSeconds'),h*.001,'target time')
        close(f(z,'horizonSeconds'),h*.001,'horizon time')
        close(f(z,'predictedPosition')-f(z,'truePosition'),f(z,'truthError'),'truth error identity')
        close(f(z,'predictedPosition')-f(z,'measuredPosition'),f(z,'measurementError'),'measurement error identity')
        close(f(z,'posteriorPosition')-f(z,'truePosition'),f(z,'posteriorTruthError'),'posterior error identity')
        check(int(z['nonfinite'])==0 and int(z['learnedCandidateNonfinite'])==0,'all forecasts expected finite')
        check(int(z['reversalLabelAvailable'])==int(z['nearReversal'])+int(z['awayFromReversal']),'event partition')
        check(o>=201 and int(z['targetInStartup'])==0,'startup excluded')
        dk=k[:3]+(o,);dv=(z['correctionWeight'],z['correctionReason'])
        check(dk not in decisions or decisions[dk]==dv,'weight and reason fixed across horizon')
        decisions[dk]=dv
        if z['modelName'].startswith('Weighted'):
            check(f(z,'correctionWeight') in [0,.25,.5,1],'allowed weights')
    m={}
    for k,g in groups.items():
        oi=tuple(int(z['originIndex']) for z in g);origins[k]=oi
        check(oi==tuple(range(201,2742,20)), 'exact common origins')
        m[k]=metrics(g)
        for event in ['all','nearReversal','awayFromReversal']:
            part=g if event=='all' else [z for z in g if int(z[event])]
            if part:
                eventgroups[k+(event,)]=part;eventmetrics[k+(event,)]=metrics(part)
    check(len(groups)==len(pr),'per-run coverage')
    for z in pr:
        q=m[key(z)]
        for name in ['truthRMSE','measurementRMSE','posteriorTruthRMSE','forecastCount','nonfiniteForecastCount']:close(z[name],q[name],name)
        close(z['peakAbsoluteError'],q['truthMaxAbsoluteError'],'peak')
        c=sum(abs(f(x,'truthError'))>math.radians(10) for x in groups[key(z)])
        close(z['catastrophicForecastCount'],c,'catastrophic count');close(z['catastrophicFraction'],c/q['forecastCount'],'catastrophic fraction')
    sg=defaultdict(list)
    for z in pr:sg[skey(z)].append(z)
    check(len(sg)==len(s),'summary coverage')
    for z in s:
        part=sg[skey(z)]
        close(z['runCount'],len(part),'summary run count')
        for name in ['truthRMSE','measurementRMSE','posteriorTruthRMSE']:close(z[name],np.mean([f(x,name) for x in part]),'equal-trajectory '+name)
        close(z['medianTruthRMSE'],np.median([f(x,'truthRMSE') for x in part]),'median')
        close(z['worstTruthRMSE'],max(f(x,'truthRMSE') for x in part),'worst')
        close(z['peakAbsoluteError'],max(f(x,'peakAbsoluteError') for x in part),'peak')
        for name in ['forecastCount','catastrophicForecastCount','nonfiniteForecastCount']:close(z[name],sum(f(x,name) for x in part),'summary '+name)
        close(z['catastrophicFraction'],f(z,'catastrophicForecastCount')/f(z,'forecastCount'),'summary catastrophic fraction')
    check(len(er)==len(eventmetrics),'event run coverage')
    esg=defaultdict(list)
    for z in er:
        k=key(z)+(z['eventGroup'],);q=eventmetrics[k]
        for name,value in q.items():close(z[name],value,'event '+name)
        esg[skey(z)+(z['eventGroup'],)].append(q)
    for z in es:
        part=esg[skey(z)+(z['eventGroup'],)]
        close(z['runCount'],len(part),'event summary run count')
        if not part: continue
        for name in part[0]:
            a=[q[name] for q in part]
            value=sum(a) if name.endswith('Count') else max(a) if name.endswith('MaxAbsoluteError') else np.mean(a)
            close(z[name],value,'event summary '+name)
    for z in pairs:
        k=key(z)+(z['eventGroup'],);bk=(z['baseline'],)+k[1:]
        a=eventmetrics[k];b=eventmetrics[bk]
        check(tuple(x['originIndex'] for x in eventgroups[k])==tuple(x['originIndex'] for x in eventgroups[bk]),'paired origins')
        close(z['modelTruthRMSE'],a['truthRMSE'],'pair model')
        close(z['baselineTruthRMSE'],b['truthRMSE'],'pair baseline')
        close(z['truthRMSEDelta'],a['truthRMSE']-b['truthRMSE'],'pair delta')
        close(z['modelWins'],a['truthRMSE']<b['truthRMSE'],'pair win')
        check(int(z['pairFailed'])==0 and int(z['bothFailed'])==0,'pair failures')
    if (folder/'weight_usage.csv').exists():
        for z in rows(folder/'weight_usage.csv'):
            part=[x for k,g in groups.items() if k[0]==z['modelName'] and k[1]==z['regime'] and k[-1]==50 for x in g]
            close(z['originCount'],len(part),'weight count')
            close(z['meanWeight'],np.mean([f(x,'correctionWeight') for x in part]),'mean weight')
            close(z['physicsFallbackFraction'],np.mean([f(x,'correctionWeight')==0 for x in part]),'fallback fraction')
    return {'endpoints':len(e),'perRunRows':len(pr),'summaryRows':len(s),'eventRunRows':len(er),'eventSummaryRows':len(es),'pairedRows':len(pairs),'seeds':sorted({int(z['seed']) for z in pr}),'maxNumericDelta':maxdiff}

def resolve_run(pointer):
    folder=json.loads(pointer.read_text(encoding='utf-8-sig'))['folder']
    path=(pointer.parent/folder).resolve()
    check(path.is_dir(),'latest pointer target exists: '+str(pointer))
    return path

base=resolve_run(ROOT/'results/latest_run.json')
diag=resolve_run(ROOT/'results/diagnostics/latest_diagnostics.json')
corr=resolve_run(ROOT/'results/correction_studies/latest_correction_study.json')
result['resolvedRuns']={'original':str(base),'diagnostics':str(diag),'correction':str(corr)}
result['diagnostics']=audit_run(diag,'event_paired_comparisons.csv',102400)
result['correction']=audit_run(corr,'paired_comparisons.csv',199680)
baseplan=json.loads((base/'study_plan.json').read_text());cplan=json.loads((corr/'study_plan.json').read_text())
sets=[set(baseplan[x]) for x in ['trainingSeeds','validationSeeds','testSeeds']]+[set(cplan[x]) for x in ['coreTestSeeds','transientSeeds','changedControllerSeeds']]
check([len(s) for s in sets]==[24,12,40,40,6,6],'current-study split counts')
for i,a in enumerate(sets):
    for b in sets[i+1:]:check(not(a&b),'split overlap')
check(set(result['diagnostics']['seeds'])==sets[2],'original seed coverage')
check(set(result['correction']['seeds'])==sets[3]|sets[4]|sets[5],'fresh seed coverage')
candidates=rows(corr/'validation_candidates.csv');selection=json.loads((corr/'selection_frozen.json').read_text())
for s in selection['selection']:
    group=[z for z in candidates if z['baseModel']==s['baseModel']]
    eligible=[z for z in group if int(z['eligible'])]
    best=min(eligible,key=lambda z:f(z,'validationRMSE_rad'))
    check(int(best['candidateId'])==s['candidateId'],'chosen validation minimum')
    for z in group:check(bool(int(z['eligible']))==(f(z,'nominalValidationRMSE_rad')<=f(z,'nominalLimit_rad') and math.isfinite(f(z,'validationRMSE_rad'))),'eligibility arithmetic')
    close(best['validationRMSE_rad'],s['validationRMSE_rad'],'selection score')
result['selection']={'candidateIds':[s['candidateId'] for s in selection['selection']],'uniqueSeedsAcrossAllSplits':len(set.union(*sets))}
old=json.loads((ROOT/'provenance/package_manifest_v0_1.json').read_text());frozen=[]
for z in old['files']:
    if z['path'].startswith('reference_project/') or z['path'].startswith('results/'+base.name+'/') or z['path']=='results/latest_run.json':
        file=ROOT/z['path'];digest=hashlib.sha256(file.read_bytes()).hexdigest()
        check(digest==z['sha256'],'original artifact hash '+z['path']);frozen.append(z['path'])
result['immutableHashesChecked']=len(frozen)
original=rows(base/'forecast_per_run.csv');diagnostic=rows(diag/'forecast_per_run.csv')
od={key(z):z for z in original};dd={key(z):z for z in diagnostic}
check(od.keys()==dd.keys(),'original diagnostic coverage')
for k,z in od.items():
    for name in z:
        if name in ['modelName','regime','runName']:check(z[name]==dd[k][name],'original diagnostic label')
        else:close(z[name],dd[k][name],'original diagnostic '+name)
for z in rows(base/'paired_comparisons_50ms.csv'):
    group=[x for x in original if x['regime']==z['regime'] and int(x['horizonSamples'])==50]
    a=sorted([x for x in group if x['modelName']==z['baseline']],key=lambda q:q['seed'])
    b=sorted([x for x in group if x['modelName']=='EDMD hybrid'],key=lambda q:q['seed'])
    check([x['seed'] for x in a]==[x['seed'] for x in b],'original pair seeds')
    ma=np.mean([f(x,'truthRMSE') for x in a]);mb=np.mean([f(x,'truthRMSE') for x in b])
    improvement=100*(1-mb/ma);wins=sum(f(y,'truthRMSE')<f(x,'truthRMSE') for x,y in zip(a,b))
    close(z['baselineMeanRMSE_deg'],math.degrees(ma),'original baseline mean')
    close(z['EDMDMeanRMSE_deg'],math.degrees(mb),'original EDMD mean')
    close(z['improvementPercent'],improvement,'original improvement')
    close(z['pairedWins'],wins,'original wins')
    close(z['comparisonPass'],improvement>=10 and wins>=7,'original screen')
spectra=rows(diag/'singular_spectrum.csv');modeldiag=rows(diag/'model_diagnostics.csv')
for z in modeldiag:
    group=[x for x in spectra if x['modelName']==z['modelName']];sing=np.array([f(x,'singularValue') for x in group]);ridge=f(z,'ridge')
    check(np.all(sing[:-1]>=sing[1:]),'descending spectrum')
    keep=sing>f(z,'svdTolerance')*sing[0]
    close(z['storedRegressorRank'],sum(keep),'rank stored');close(z['recomputedRetainedRank'],sum(keep),'rank recomputed')
    close(z['positiveSpectrumCondition'],max(sing)/min(sing[sing>0]),'condition')
    for i,x in enumerate(group):
        close(x['retained'],keep[i],'spectrum retention')
        close(x['ridgeFilterFactor'],sing[i]**2/(sing[i]**2+ridge) if keep[i] else 0,'ridge filter')
        close(x['inverseGain'],sing[i]/(sing[i]**2+ridge) if keep[i] else 0,'ridge inverse gain')
roll=rows(diag/'lifted_rollout_diagnostics.csv');rg=defaultdict(list)
for z in roll:
    if z['rowScope']=='run':rg[skey(z)].append(z)
for z in roll:
    if z['rowScope']!='trajectory_equal_weight':continue
    part=rg[skey(z)];close(z['runCount'],len(part),'rollout run count')
    for name in ['forecastCount','nonfiniteForecastCount','oneStepPairCount','oneStepNonfiniteCount','consistencyNonfiniteCount']:close(z[name],sum(f(x,name) for x in part),'rollout count')
    for name in ['nonfiniteForecastFraction','oneStepLiftedRelativeError','oneStepInnovationRMSE','oneStepInnovationNormalizedRMSE','constantCoordinateRMSE','quadraticConsistencyRMSE','quadraticConsistencyRelativeError']:close(z[name],np.mean([f(x,name) for x in part]),'rollout equal-trajectory metric')
result['additionalChecks']={'originalPerRunAllFields':len(od),'original50msPairComparisons':12,'singularSpectrumRows':len(spectra),'liftedRolloutRows':len(roll)}
result['assertionsPassed']=checks;result['maxNumericDelta']=maxdiff
result['status']='passed'
result['completedUtc']=datetime.now(timezone.utc).isoformat()
serialized=json.dumps(result,indent=2,allow_nan=False)
if OUT:
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(serialized+'\n',encoding='utf-8')
print(serialized)
