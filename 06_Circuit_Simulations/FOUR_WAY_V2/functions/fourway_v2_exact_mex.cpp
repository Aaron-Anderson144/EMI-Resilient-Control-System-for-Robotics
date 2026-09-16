// PLAN-V2 conditional loaded circuit plus persistent delayed receiver.
// Derived as a separate implementation from the preserved PLAN-V1 engine.
// All original PWL knots are processed; modal state never resets at a pulse.
// Range envelopes and root isolation cover continuous pin/differential voltage.
#include "mex.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <complex>
#include <vector>
#include <limits>
using Z=std::complex<double>;
using Vec=std::array<Z,3>;
using Row=std::vector<double>;
static constexpr double JOINT=1e-12, ROOT_TOL=2e-17;
static constexpr size_t BASE=80,HISTORY=40;
struct Model { Vec l;Z V[3][3],W[3][3],F[3][3];const double *kt,*dv,*orig;
 size_t nk,np;double ramp,nativeEnd,returnEnd,rise,fall,delayRise,delayFall,gx[3],gc,gs;int inertial; };
struct Flow {Vec c0,c1,z,ex;const Model*m;double driver,driverSlope;};
struct Event {double t;int kind,slot;double threshold;int dir;std::array<double,3>x;int a;};
struct Change {double t;int a,b;bool isa;};
struct Pending {double t;int a;};
const mxArray* field(const mxArray*a,const char*n){auto r=mxGetField(a,0,n);if(!r)mexErrMsgIdAndTxt("FOURWAY_V2:MexField","Missing %s",n);return r;}
void matrix(const mxArray*a,Z out[3][3]){auto p=mxGetDoubles(a);for(int i=0;i<3;++i)for(int j=0;j<3;++j)out[i][j]=Z(p[i+3*j],p[i+3*(j+3)]);}
Vec modal(const Model&m,const double*x){Vec y{};for(int i=0;i<3;++i)for(int j=0;j<3;++j)y[i]+=m.W[i][j]*x[j];return y;}
std::array<double,3> physical(const Model&m,const Vec&y){std::array<double,3>x{};for(int i=0;i<3;++i)for(int j=0;j<3;++j)x[i]+=(m.V[i][j]*y[j]).real();return x;}
Vec value(const Flow&f,double t){Vec y;for(int i=0;i<3;++i)y[i]=f.c0[i]+f.c1[i]*t+f.z[i]*std::exp(f.m->l[i]*t);return y;}
struct Scalar {double c0,c1;Vec a;const Model*m;};
// signal1=vd,2=vp,3=vn,4=vcm,5=encoder-driver ground.
Scalar scalar(const Flow&f,int signal,double threshold=0){Scalar s{};s.m=f.m;s.c0=-threshold;
 for(int i=0;i<3;++i){Z w=signal==1?f.m->V[0][i]-f.m->V[1][i]:signal==2?f.m->V[0][i]:signal==3?f.m->V[1][i]:signal==4?(f.m->V[0][i]+f.m->V[1][i])*.5:Z(0);
  if(signal==5)for(int j=0;j<3;++j)w+=f.m->gx[j]*f.m->V[j][i];
  s.c0+=(w*f.c0[i]).real();s.c1+=(w*f.c1[i]).real();s.a[i]=w*f.z[i];}
 if(signal==5){s.c0+=f.m->gc+f.m->gs*f.driver;s.c1+=f.m->gs*f.driverSlope;}return s;
}
double val(const Scalar&s,double t){double v=s.c0+s.c1*t;for(int i=0;i<3;++i)v+=(s.a[i]*std::exp(s.m->l[i]*t)).real();return v;}
double atEnd(const Scalar&s,const Flow&f,double dt){double v=s.c0+s.c1*dt;for(int i=0;i<3;++i)v+=(s.a[i]*f.ex[i]).real();return v;}
std::pair<double,double> bounds(const Scalar&s,double lo,double hi,bool derivative=false){
 double lower=derivative?s.c1:s.c0+std::min(s.c1*lo,s.c1*hi),upper=derivative?s.c1:s.c0+std::max(s.c1*lo,s.c1*hi);
 for(int i=0;i<3;++i){Z a=s.a[i]*(derivative?s.m->l[i]:Z(1));double l=s.m->l[i].real();
  if(std::abs(s.m->l[i].imag())<1e-12){double v0=a.real()*std::exp(l*lo),v1=a.real()*std::exp(l*hi);lower+=std::min(v0,v1);upper+=std::max(v0,v1);}
  else{double amp=std::abs(a),r0=amp*std::exp(l*lo),r1=amp*std::exp(l*hi),p0=std::arg(a)+s.m->l[i].imag()*lo,p1=std::arg(a)+s.m->l[i].imag()*hi;if(p0>p1)std::swap(p0,p1);
   double cmin=std::min(std::cos(p0),std::cos(p1)),cmax=std::max(std::cos(p0),std::cos(p1));constexpr double PI=3.14159265358979323846;
   if(p1-p0>=2*PI){cmin=-1;cmax=1;}else{long k0=(long)std::ceil(p0/PI),k1=(long)std::floor(p1/PI);for(long k=k0;k<=k1;++k){if(k%2==0)cmax=1;else cmin=-1;}}
   lower+=std::min({r0*cmin,r0*cmax,r1*cmin,r1*cmax});upper+=std::max({r0*cmin,r0*cmax,r1*cmin,r1*cmax});}}
 return {lower,upper};
}
// Intersection of two independent analytical enclosures. No sampled-only gate.
std::pair<double,double> range(const Scalar&s,const Flow&f,double dt){
 double v0=s.c0,v1=atEnd(s,f,dt),m2=0;for(int i=0;i<3;++i){v0+=s.a[i].real();m2+=std::abs(s.a[i]*s.m->l[i]*s.m->l[i]);}
 double e=m2*dt*dt/8,lo=std::min(v0,v1)-e,hi=std::max(v0,v1)+e;
 if(e>1e-5){auto b=bounds(s,0,dt);lo=std::max(lo,b.first);hi=std::min(hi,b.second);}
 return {lo,hi};
}
double bisect(const Scalar&s,double lo,double hi,double vl){for(int i=0;i<80&&hi-lo>ROOT_TOL;++i){double mid=(lo+hi)*.5,v=val(s,mid);if((vl<0)==(v<0)){lo=mid;vl=v;}else hi=mid;}return (lo+hi)*.5;}
void roots(const Scalar&s,double lo,double hi,std::vector<std::pair<double,int>>&out,int depth=0){
 auto b=bounds(s,lo,hi);if(b.first>0||b.second<0)return;
 double vl=val(s,lo),vh=val(s,hi);auto db=bounds(s,lo,hi,true);bool mono=db.first>=0||db.second<=0;
 if(mono){if((vl<0&&vh>0)||(vl>0&&vh<0))out.push_back({bisect(s,lo,hi,vl),vh>vl?1:-1});
  else if(vl==0&&vh!=0)out.push_back({lo,vh>0?1:-1});else if(vh==0&&vl!=0)out.push_back({hi,vh>vl?1:-1});return;}
 if(hi-lo<=ROOT_TOL||depth>64)mexErrMsgIdAndTxt("FOURWAY_V2:UnresolvedGrazing","Cannot certify complete threshold-root order; retain this run as rejected diagnostics.");
 double mid=(lo+hi)*.5;roots(s,lo,mid,out,depth+1);roots(s,mid,hi,out,depth+1);
}
int gray(int a,int b){if(!a&&!b)return 0;if(a&&!b)return 1;if(a&&b)return 2;return 3;}
int increment(int pa,int pb,int a,int b){int d=(gray(a,b)-gray(pa,pb)+4)%4;return d==1?1:d==3?-1:0;}
mxArray* rows(const std::vector<Row>&r,size_t n){auto a=mxCreateDoubleMatrix(r.size(),n,mxREAL);auto p=mxGetDoubles(a);for(size_t i=0;i<r.size();++i)for(size_t j=0;j<n;++j)p[i+j*r.size()]=r[i][j];return a;}
void mexFunction(int nlhs,mxArray*plhs[],int nrhs,const mxArray*prhs[]){
 if(nrhs<4||nlhs<4)mexErrMsgIdAndTxt("FOURWAY_V2:MexUsage","Use [state,events,decoder,boundaries,queries,logic]=exact(config,state,end,transitions,optionalQueries).");
 Model m;auto c=prhs[0];auto la=mxGetDoubles(field(c,"lambda"));for(int i=0;i<3;++i)m.l[i]=Z(la[i],la[i+3]);
 matrix(field(c,"V"),m.V);matrix(field(c,"W"),m.W);matrix(field(c,"forcing"),m.F);
 m.kt=mxGetDoubles(field(c,"knots"));m.dv=mxGetDoubles(field(c,"slopes"));m.orig=mxGetDoubles(field(c,"origins"));m.nk=mxGetNumberOfElements(field(c,"knots"));m.np=mxGetNumberOfElements(field(c,"origins"));
 m.ramp=mxGetScalar(field(c,"transition_s"));m.nativeEnd=mxGetScalar(field(c,"native_end_s"));m.returnEnd=mxGetScalar(field(c,"return_end_s"));
 m.rise=mxGetScalar(field(c,"rise_V"));m.fall=mxGetScalar(field(c,"fall_V"));m.delayRise=mxGetScalar(field(c,"latency_rise_s"));m.delayFall=mxGetScalar(field(c,"latency_fall_s"));m.inertial=(int)mxGetScalar(field(c,"pulse_law"));
 auto gx=mxGetDoubles(field(c,"ground_x"));for(int i=0;i<3;++i)m.gx[i]=gx[i];m.gc=mxGetScalar(field(c,"ground_constant"));m.gs=mxGetScalar(field(c,"ground_driver"));
 size_t ns=mxGetNumberOfElements(prhs[1]);if(ns<BASE)mexErrMsgIdAndTxt("FOURWAY_V2:State","V2 state requires 80 fixed entries plus pending events.");
 std::vector<double>s(mxGetDoubles(prhs[1]),mxGetDoubles(prhs[1])+ns);double end=mxGetScalar(prhs[2]);
 auto tr=mxGetDoubles(prhs[3]);size_t nt=mxGetM(prhs[3]),ti=0;auto qt=nrhs>4?mxGetDoubles(prhs[4]):nullptr;size_t nq=nrhs>4?mxGetNumberOfElements(prhs[4]):0,qi=0;
 double t=s[0],driver=s[4],driverSlope=s[5],rampEnd=s[6],domainTime=t;int ia=(int)s[7],ib=(int)s[8],ra=(int)s[9],request=(int)s[20],mask=(int)s[35];
 bool failed=s[13]!=0,stress=s[21]!=0;size_t pulse=(size_t)s[14],knot=(size_t)s[15];int ideal=(int)s[16];
 Vec y=modal(m,&s[1]);std::vector<Event>events;std::vector<Change>changes;std::vector<Row>boundary,query,logic;
 std::vector<Pending>pending;for(size_t j=BASE;j+1<ns;j+=2)pending.push_back({s[j],(int)s[j+1]});size_t head=0;
 std::vector<std::pair<double,Vec>>expCache;
 auto flush=[&](double until){while(head<pending.size()&&pending[head].t<=until){double when=pending[head].t;int a=pending[head].a;++head;while(head<pending.size()&&pending[head].t==when){a=pending[head].a;++head;}
   if(a!=ra){ra=a;changes.push_back({when,a,0,true});logic.push_back({when,2.,(double)a,when});}}};
 auto accrue=[&](double until){double dt=until-domainTime;if(mask)s[24]+=dt;if(mask&1)s[25]+=dt;if(mask&2)s[26]+=dt;if(mask&4)s[27]+=dt;if(mask&3)s[71]+=dt;domainTime=until;};
 auto rejectDomain=[&](double when){failed=true;if(std::isnan(s[23]))s[23]=when;};
 auto initial=physical(m,y);int actualMask=(std::abs(initial[0])>15?1:0)|(std::abs(initial[1])>15?2:0)|(std::abs(initial[0]-initial[1])>15?4:0);
 if(actualMask){mask|=actualMask;rejectDomain(t);}if(std::abs(initial[0])>18||std::abs(initial[1])>18||std::abs(initial[0]-initial[1])>18)stress=true;
 auto logBoundary=[&](int kind,double dv){auto x=physical(m,y);boundary.push_back({t,(double)kind,x[0],x[1],x[2],driver,dv});};
 while(true){
   if(driverSlope!=0&&t>=rampEnd){driver=2*ia-1;driverSlope=0;logBoundary(2,0);}
   while(pulse<m.np&&t>=m.orig[pulse]+m.kt[m.nk-1]){if(m.returnEnd==m.kt[m.nk-1])logBoundary(6,0);logBoundary(4,0);++pulse;knot=0;}
   if(pulse<m.np&&t>=m.orig[pulse]){if(knot==0&&std::abs(t-m.orig[pulse])<1e-15)logBoundary(3,m.dv[0]);
     while(knot+1<m.nk&&t>=m.orig[pulse]+m.kt[knot+1]){++knot;if(m.kt[knot]==m.nativeEnd)logBoundary(5,knot<m.nk-1?m.dv[knot]:0);if(m.kt[knot]==m.returnEnd)logBoundary(6,knot<m.nk-1?m.dv[knot]:0);}}
   while(ti<nt&&tr[ti]<=t){int a=(int)tr[ti+nt],b=(int)tr[ti+2*nt];ideal+=increment(ia,ib,a,b);
     if(a!=ia){driverSlope=((2*a-1)-driver)/m.ramp;rampEnd=t+m.ramp;ia=a;logBoundary(1,0);}if(b!=ib){changes.push_back({tr[ti],0,b,false});ib=b;}++ti;}
   while(qi<nq&&qt[qi]<=t){auto x=physical(m,y);query.push_back({qt[qi],x[0],x[1],x[2]});++qi;}
   if(t>=end)break;
   double next=end,dv=0;if(ti<nt)next=std::min(next,tr[ti]);if(driverSlope!=0)next=std::min(next,rampEnd);if(qi<nq)next=std::min(next,qt[qi]);
   if(pulse<m.np){if(t<m.orig[pulse])next=std::min(next,m.orig[pulse]);else{next=std::min(next,m.orig[pulse]+m.kt[knot+1]);dv=m.dv[knot];}}
   double dt=next-t;if(!(dt>0))mexErrMsgIdAndTxt("FOURWAY_V2:TimeProgress","Nonpositive interval.");
   Flow f;f.m=&m;f.driver=driver;f.driverSlope=driverSlope;
   bool cached=false;for(auto&entry:expCache)if(entry.first==dt){f.ex=entry.second;cached=true;break;}
   if(!cached){for(int i=0;i<3;++i)f.ex[i]=std::exp(m.l[i]*dt);if(expCache.size()<128)expCache.push_back({dt,f.ex});}
   for(int i=0;i<3;++i){Z f0=m.F[i][0]+m.F[i][1]*driver+m.F[i][2]*dv,f1=m.F[i][1]*driverSlope;f.c1[i]=-f1/m.l[i];f.c0[i]=(f.c1[i]-f0)/m.l[i];f.z[i]=y[i]-f.c0[i];}
   Scalar signals[5];std::pair<double,double>ranges[5];for(int j=0;j<5;++j){signals[j]=scalar(f,j+1);ranges[j]=range(signals[j],f,dt);}
   s[28]=std::min(s[28],ranges[1].first);s[29]=std::max(s[29],ranges[1].second);s[30]=std::min(s[30],ranges[2].first);s[31]=std::max(s[31],ranges[2].second);
   s[32]=std::min(s[32],ranges[0].first);s[33]=std::max(s[33],ranges[0].second);s[17]=std::max(s[17],std::max(std::abs(ranges[3].first),std::abs(ranges[3].second)));
   s[18]=std::max(s[18],std::max(std::abs(ranges[0].first),std::abs(ranges[0].second)));s[34]=std::max(s[34],std::max(std::abs(ranges[4].first),std::abs(ranges[4].second)));
   s[38]=std::min(s[38],ranges[3].first);s[39]=std::max(s[39],ranges[3].second);
   std::vector<Event>segment;
   for(int kind=1;kind<=7;++kind){int signal=kind==1?0:kind==2||kind==5?1:kind==3||kind==6?2:0;
     for(int side=0;side<2;++side){double level=kind==1?(side==0?m.fall:m.rise):(side==0?-1.:1.)*(kind<=4?15.:18.);
       if(ranges[signal].first>level||ranges[signal].second<level)continue;
       Scalar sc=signals[signal];sc.c0-=level;std::vector<std::pair<double,int>>rr;roots(sc,0,dt,rr);
       for(auto root:rr){auto x=physical(m,value(f,root.first));segment.push_back({t+root.first,kind,2*(kind-1)+side,level,root.second,x,ra});}}}
   std::stable_sort(segment.begin(),segment.end(),[](const Event&a,const Event&b){return a.t<b.t;});
   for(auto&e:segment){size_t h=HISTORY+2*e.slot;double gap=e.t-s[h];
     if(std::abs(gap)<=ROOT_TOL){if(e.dir==(int)s[h+1])continue;mexErrMsgIdAndTxt("FOURWAY_V2:UnresolvedRootPair","Opposite-direction roots are below root resolution.");}
     s[h]=e.t;s[h+1]=e.dir;flush(e.t);
     if(e.kind>=2&&e.kind<=4){accrue(e.t);int bit=1<<(e.kind-2);bool outward=(e.threshold>0&&e.dir>0)||(e.threshold<0&&e.dir<0);if(outward){mask|=bit;rejectDomain(e.t);}else mask&=~bit;}
     if(e.kind>=5&&((e.threshold>0&&e.dir>0)||(e.threshold<0&&e.dir<0)))stress=true;
     if(e.kind==1){int a=request;if(e.threshold==m.rise&&e.dir>0)a=1;if(e.threshold==m.fall&&e.dir<0)a=0;
       if(a!=request){request=a;double due=e.t+(a?m.delayRise:m.delayFall);logic.push_back({e.t,1.,(double)a,due});
         if(m.inertial){pending.clear();head=0;if(a!=ra)pending.push_back({due,a});}
         else{if(s[68]>=0&&due<s[68])mexErrMsgIdAndTxt("FOURWAY_V2:TransportOvertaking","Assumed unequal delays reorder causal input events.");pending.push_back({due,a});s[68]=due;}
         flush(e.t);}}
     e.a=ra;events.push_back(e);
   }
   for(int i=0;i<3;++i)y[i]=f.c0[i]+f.c1[i]*dt+f.z[i]*f.ex[i];driver+=driverSlope*dt;t=next;s[19]+=1;
 }
 flush(end);accrue(end);
 std::stable_sort(changes.begin(),changes.end(),[](const Change&a,const Change&b){return a.t<b.t;});
 int pa=(int)s[11],pb=(int)s[12],count=(int)s[10];std::vector<Row>dec;
 if(!changes.empty()&&s[22]>=0&&changes[0].t-s[22]<=JOINT)
   mexErrMsgIdAndTxt("FOURWAY_V2:CrossPacketJointAmbiguity","A new A/B event is within 1 ps of an event already exposed to a preceding sample; reject retrospective count repair.");
 for(size_t i=0;i<changes.size();){double first=changes[i].t,when=first;int a=pa,b=pb;size_t j=i;
   while(j<changes.size()&&changes[j].t-first<=JOINT){when=changes[j].t;if(changes[j].isa)a=changes[j].a;else b=changes[j].b;++j;}
   if(a!=pa||b!=pb){bool inv=(a!=pa&&b!=pb);int inc=inv?0:increment(pa,pb,a,b);count+=inc;
     dec.push_back({when,(double)a,(double)b,(double)inc,(double)count,(double)inv,(double)pa,(double)pb});pa=a;pb=b;s[22]=when;}i=j;}
 auto x=physical(m,y);s.resize(BASE);s[0]=t;for(int i=0;i<3;++i)s[1+i]=x[i];s[4]=driver;s[5]=driverSlope;s[6]=rampEnd;s[7]=ia;s[8]=ib;s[9]=ra;s[10]=count;s[11]=pa;s[12]=pb;
 s[13]=failed;s[14]=(double)pulse;s[15]=(double)knot;s[16]=ideal;s[20]=request;s[21]=stress;s[35]=mask;s[72]=pending.size()-head;
 for(size_t j=head;j<pending.size();++j){s.push_back(pending[j].t);s.push_back(pending[j].a);}
 plhs[0]=mxCreateDoubleMatrix(s.size(),1,mxREAL);std::copy(s.begin(),s.end(),mxGetDoubles(plhs[0]));
 std::vector<Row>er;for(auto&e:events)er.push_back({e.t,(double)e.kind,e.threshold,(double)e.dir,e.x[0],e.x[1],e.x[2],(double)e.a});
 plhs[1]=rows(er,8);plhs[2]=rows(dec,8);plhs[3]=rows(boundary,7);if(nlhs>4)plhs[4]=rows(query,4);if(nlhs>5)plhs[5]=rows(logic,4);
}
