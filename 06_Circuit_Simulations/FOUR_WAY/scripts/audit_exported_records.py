from pathlib import Path
import argparse,csv,json,math,hashlib
import numpy as np

def rows(path):
    with path.open(newline='',encoding='utf-8-sig') as f:return list(csv.DictReader(f))

def numeric(data,key):
    return np.array([float(r[key]) for r in data])

def logical(data,key):
    return np.array([r[key].lower() in ('1','true') for r in data])

def audit_record(folder):
    data=rows(folder/'controller.csv');t=numeric(data,'time_s')
    checks={}
    checks['complete_grid']=len(t)==3001 and np.max(np.abs(t-np.arange(3001)*.001))<1e-14
    checks['finite_plant_command']=all(np.isfinite(numeric(data,k)).all() for k in ('position_rad','velocity_rad_s','current_A','command_V'))
    checks['fresh_timestamps']=np.array_equal(numeric(data,'sourceIndex'),np.arange(1,len(t)+1)) and logical(data,'sampleReceived').all()
    position=numeric(data,'position_rad');ideal=numeric(data,'idealCount');count=numeric(data,'decodedCount')
    shadow=numeric(data,'shadowDecodedCount');command=numeric(data,'command_V');mode=numeric(data,'mode')
    delta=2*np.pi/4096
    checks['quantization_bins']=np.max(np.abs(position-ideal*delta))<=delta/2+1e-12
    checks['decoded_measurement']=np.max(np.abs(numeric(data,'receivedMeasurement_rad')-count*delta))<2e-14
    checks['persistent_count_error']=np.array_equal(ideal-count,numeric(data,'idealMinusDecodedCount'))
    checks['separate_shadow_oracle']=np.array_equal(count-shadow,numeric(data,'emiCountError'))
    checks['bounded_command']=np.max(np.abs(command))<=24+1e-12
    checks['stopped_command_zero']=np.all(command[mode==4]==0)
    threshold_events=rows(folder/'receiver_threshold_events.csv')
    exits=[float(e['time_s']) for e in threshold_events if float(e['kind_1diff_2common'])==2 and float(e['threshold_V'])*float(e['direction'])>0]
    expected_domain=t>=min(exits)-1e-14 if exits else np.zeros(len(t),dtype=bool)
    checks['persistent_domain_rejection']=np.array_equal(expected_domain,logical(data,'receiverDomainFailed'))
    gray={(0,0):0,(1,0):1,(1,1):2,(0,1):3}
    for name,expected in [('receiver',count),('shadow',shadow)]:
        events=rows(folder/(name+'_decoder_events.csv'))
        previous=(0,0);total=0;times=[];totals=[];valid=True
        for e in events:
            now=(int(float(e['A'])),int(float(e['B'])))
            reported_previous=(int(float(e['previous_A'])),int(float(e['previous_B'])))
            d=(gray[now]-gray[previous])%4
            increment={0:0,1:1,2:0,3:-1}[d]
            invalid=int(now[0]!=previous[0] and now[1]!=previous[1]);total+=increment
            valid=valid and previous==reported_previous and increment==float(e['increment']) and invalid==float(e['invalid']) and total==float(e['count'])
            previous=now;times.append(float(e['time_s']));totals.append(total)
        event_times=np.asarray(times)
        checks[name+'_event_grid']=bool(np.isfinite(event_times).all() and (np.diff(event_times)>0).all() and (event_times>=0).all() and (event_times<=3+1e-14).all())
        checks[name+'_independent_gray_decode']=bool(valid)
        index=np.searchsorted(np.array(times),t+1e-14,side='right')
        reconstructed=np.r_[0,totals][index]
        checks[name+'_events_before_packets']=np.array_equal(reconstructed,expected)
    source=json.loads((folder/'receiver_source.json').read_text())
    if source['exposed']:
        origins=np.array(source['pulse_origins_s'])
        checks['two_hundred_source_pulses']=len(origins)==200 and np.max(np.abs(np.diff(origins[:100])-50e-6))<1e-15 and np.max(np.abs(np.diff(origins[100:])-50e-6))<1e-15
    else:
        checks['clean_no_pulses']=len(source['pulse_origins_s'])==0
        checks['clean_count_sample_bound']=np.max(np.abs(ideal-count))<=1
    failed=[k for k,v in checks.items() if not v]
    return {'record':folder.name,'checks':len(checks),'passed':len(checks)-len(failed),'failed':failed}

def audit_campaign(path):
    record_folders=sorted(p.parent for p in path.glob('*/controller.csv'))
    assert record_folders,'No record exports found: '+str(path)
    assert (path/'metrics.csv').exists(),'No completed paired metrics: '+str(path)
    if (path/'record_index.csv').exists():
        index=rows(path/'record_index.csv');names=[r['Record'] for r in index]
        assert len(set(names))==len(names) and set(names)=={p.name for p in record_folders},'Record index/discovery mismatch'
        partition=rows(path/'metrics.csv')[0]['Partition']
        expected={'development':16,'evaluation':96}[partition]
        assert len(names)==expected,'Incomplete campaign: expected '+str(expected)
        assert len(rows(path/'metrics.csv'))==expected//2,'Incomplete metric pairs'
    else:
        assert path.name=='smoke_01' and {p.name for p in record_folders}=={'clean','exposed'},'Missing production record index'
    record_checks=[audit_record(p) for p in record_folders]
    metric_checks=[]
    if (path/'metrics.csv').exists():
        for m in rows(path/'metrics.csv'):
            name=m['Fixture']+'_'+m['Arm']
            exposed_path=path/(name+'_exposed');clean_path=path/(name+'_clean')
            if not exposed_path.is_dir():exposed_path=path/'exposed';clean_path=path/'clean'
            a=rows(exposed_path/'controller.csv')
            b=rows(clean_path/'controller.csv')
            t=numeric(a,'time_s')
            pair=np.rad2deg(numeric(a,'position_rad')-numeric(b,'position_rad'))
            request=np.rad2deg(numeric(a,'position_rad')-numeric(a,'requestedReference_rad'))
            window=((t>=.24)&(t<.4))|((t>=1.69)&(t<1.85));tail=t>=2.9
            expected={'WindowPairedRMSE_deg':np.sqrt(np.mean(pair[window]**2)), 'WindowPairedPeak_deg':np.max(np.abs(pair[window])),
                      'FullPairedRMSE_deg':np.sqrt(np.mean(pair**2)), 'FullPairedPeak_deg':np.max(np.abs(pair)),
                      'RequestedRMSE_deg':np.sqrt(np.mean(request**2)), 'FinalRequestedError_deg':abs(request[-1]),
                      'TailRequestedRMSE_deg':np.sqrt(np.mean(request[tail]**2))}
            failed=[k for k,v in expected.items() if not math.isclose(v,float(m[k]),rel_tol=1e-10,abs_tol=1e-11)]
            for burst in (1,2):
                source=json.loads((exposed_path/'receiver_source.json').read_text())
                end=np.asarray(source['last_nonzero_dVa_dt_s']).reshape(-1)[burst*100-1]
                good=np.abs(pair)<=.5
                if m['Arm'] in ('SW_ONLY','COMBINED'):good=good&(numeric(a,'mode')==0)
                delay=math.nan
                for i in range(np.searchsorted(t,end),len(t)-50):
                    if good[i:i+51].all():delay=t[i]-end;break
                actual=float(m[f'Burst{burst}Recovery_s'])
                if not ((math.isnan(delay) and math.isnan(actual)) or math.isclose(delay,actual,rel_tol=1e-10,abs_tol=1e-12)):
                    failed.append(f'burst{burst}_recovery')
            metric_checks.append({'pair':name,'checks':len(expected)+2,'failed':failed})
    return {'path':str(path),'records':record_checks,'metrics':metric_checks,'all_passed':not any(r['failed'] for r in record_checks+metric_checks)}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('campaign',nargs='+');parser.add_argument('--output',required=True)
    args=parser.parse_args();campaigns=[audit_campaign(Path(p)) for p in args.campaign]
    report={'audit':'Independent Python reconstruction from exported CSV event and controller records','campaigns':campaigns,
            'all_passed':all(c['all_passed'] for c in campaigns),'physical_validation':False}
    Path(args.output).write_text(json.dumps(report,indent=2))
    print(json.dumps({'all_passed':report['all_passed'],'records':sum(len(c['records']) for c in campaigns),
                      'metric_pairs':sum(len(c['metrics']) for c in campaigns)}))
    if not report['all_passed']:raise SystemExit(1)
