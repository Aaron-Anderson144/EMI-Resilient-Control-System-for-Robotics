// PLAN-V1 exact piecewise-affine SC01A circuit. Original replay knots are
// processed in order; states are never reset, even across long DC holds.
// Each modal interval is y=c0+c1*t+(yLeft-c0)*exp(lambda*t).
// Interval enclosures prove absent roots or derivative monotonicity;
// remaining intervals are bisected, so endpoint-only glitch detection is
// not used. Unresolved grazing is an explicit rejected numerical condition.
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
struct Model { Vec l;Z V[3][3],W[3][3],F[3][3];const double *kt,*dv,*orig;size_t nk,np;double ramp,nativeEnd,returnEnd; };
struct Flow {Vec c0,c1,z; const Model *m;};
struct Event {double t;int kind;double threshold;int dir;std::array<double,3>x;int a;};
struct Change {double t;int a,b;bool isa;};
const mxArray* field(const mxArray* a,const char* n){const mxArray*r=mxGetField(a,0,n);if(!r)mexErrMsgIdAndTxt("FOURWAY:MexField","Missing field %s",n);return r;}
void matrix(const mxArray*a,Z out[3][3]){const double*p=mxGetDoubles(a);for(int i=0;i<3;++i)for(int j=0;j<3;++j)out[i][j]=Z(p[i+3*j],p[i+3*(j+3)]);}
Vec modal(const Model&m,const double*x){Vec y{};for(int i=0;i<3;++i)for(int j=0;j<3;++j)y[i]+=m.W[i][j]*x[j];return y;}
std::array<double,3> physical(const Model&m,const Vec&y){std::array<double,3>x{};for(int i=0;i<3;++i)for(int j=0;j<3;++j)x[i]+=(m.V[i][j]*y[j]).real();return x;}
Vec value(const Flow&f,double t){Vec y;for(int i=0;i<3;++i)y[i]=f.c0[i]+f.c1[i]*t+f.z[i]*std::exp(f.m->l[i]*t);return y;}
struct Scalar { double c0,c1;Vec a;const Model*m; };
Scalar scalar(const Flow&f,int kind,double threshold=0){Scalar s{};s.m=f.m;s.c0=-threshold;for(int i=0;i<3;++i){Z weight=kind==1?f.m->V[0][i]-f.m->V[1][i]:(f.m->V[0][i]+f.m->V[1][i])*0.5;s.c0+=(weight*f.c0[i]).real();s.c1+=(weight*f.c1[i]).real();s.a[i]=weight*f.z[i];}return s;}
double val(const Scalar&s,double t){double v=s.c0+s.c1*t;for(int i=0;i<3;++i)v+=(s.a[i]*std::exp(s.m->l[i]*t)).real();return v;}
std::pair<double,double> bounds(const Scalar&s,double lo,double hi,bool derivative=false){
 double lower=derivative?s.c1:s.c0+std::min(s.c1*lo,s.c1*hi),upper=derivative?s.c1:s.c0+std::max(s.c1*lo,s.c1*hi);
 for(int i=0;i<3;++i){Z a=s.a[i]*(derivative?s.m->l[i]:Z(1));double l=s.m->l[i].real();if(std::abs(s.m->l[i].imag())<1e-12){double v0=a.real()*std::exp(l*lo),v1=a.real()*std::exp(l*hi);lower+=std::min(v0,v1);upper+=std::max(v0,v1);}else{
   double amp=std::abs(a),r0=amp*std::exp(l*lo),r1=amp*std::exp(l*hi);
   double p0=std::arg(a)+s.m->l[i].imag()*lo,p1=std::arg(a)+s.m->l[i].imag()*hi;if(p0>p1)std::swap(p0,p1);
   double cmin=std::min(std::cos(p0),std::cos(p1)),cmax=std::max(std::cos(p0),std::cos(p1));
   constexpr double PI=3.14159265358979323846;
   if(p1-p0>=2*PI){cmin=-1;cmax=1;}else{long k0=(long)std::ceil(p0/PI),k1=(long)std::floor(p1/PI);for(long k=k0;k<=k1;++k){if(k%2==0)cmax=1;else cmin=-1;}}
   lower+=std::min({r0*cmin,r0*cmax,r1*cmin,r1*cmax});upper+=std::max({r0*cmin,r0*cmax,r1*cmin,r1*cmax});
 }}
 return {lower,upper};
}
double bisect(const Scalar&s,double lo,double hi,double vl){for(int i=0;i<64&&hi-lo>ROOT_TOL;++i){double mid=(lo+hi)*.5,v=val(s,mid);if((vl<0)==(v<0)){lo=mid;vl=v;}else hi=mid;}return hi;}
void roots(const Scalar&s,double lo,double hi,std::vector<std::pair<double,int>>&out,int depth=0,bool rejectGrazing=true){
 auto b=bounds(s,lo,hi);if(b.first>0||b.second<0)return;
 double vl=val(s,lo),vh=val(s,hi);auto db=bounds(s,lo,hi,true);
 bool mono=db.first>=0||db.second<=0;
 if(mono){if((vl<0&&vh>=0)||(vl>0&&vh<=0)){out.push_back({bisect(s,lo,hi,vl),vh>=vl?1:-1});}else if(vl==0&&vh!=0){out.push_back({lo,vh>0?1:-1});}return;}
 if(!rejectGrazing&&std::max(std::abs(b.first),std::abs(b.second))<1e-8)return;
 if(hi-lo<=ROOT_TOL||depth>64){if((vl<0&&vh>=0)||(vl>0&&vh<=0))out.push_back({(lo+hi)*.5,vh>=vl?1:-1});else if(rejectGrazing&&(std::abs(vl)<1e-10||std::abs(vh)<1e-10))mexErrMsgIdAndTxt("FOURWAY:UnresolvedGrazing","A threshold grazing cannot be certified; retain this run as rejected diagnostics.");return;}
 double mid=(lo+hi)*.5;roots(s,lo,mid,out,depth+1,rejectGrazing);roots(s,mid,hi,out,depth+1,rejectGrazing);
}
int gray(int a,int b){if(a==0&&b==0)return 0;if(a==1&&b==0)return 1;if(a==1&&b==1)return 2;return 3;}
int increment(int pa,int pb,int a,int b){int d=(gray(a,b)-gray(pa,pb)+4)%4;return d==1?1:d==3?-1:0;}
mxArray* rows(const std::vector<Row>&r,size_t n){mxArray*a=mxCreateDoubleMatrix(r.size(),n,mxREAL);double*p=mxGetDoubles(a);for(size_t i=0;i<r.size();++i)for(size_t j=0;j<n;++j)p[i+j*r.size()]=r[i][j];return a;}
void mexFunction(int nlhs,mxArray*plhs[],int nrhs,const mxArray*prhs[]){
 if(nrhs<4||nlhs<4)mexErrMsgIdAndTxt("FOURWAY:MexUsage","Use [state,events,decoder,boundaries,queries]=fourway_exact_mex(config,state,tEnd,transitions,optionalQueryTimes).");
 Model m;const mxArray*c=prhs[0];const double*la=mxGetDoubles(field(c,"lambda"));for(int i=0;i<3;++i)m.l[i]=Z(la[i],la[i+3]);matrix(field(c,"V"),m.V);matrix(field(c,"W"),m.W);matrix(field(c,"forcing"),m.F);
 m.kt=mxGetDoubles(field(c,"knots"));m.dv=mxGetDoubles(field(c,"slopes"));m.orig=mxGetDoubles(field(c,"origins"));m.nk=mxGetNumberOfElements(field(c,"knots"));m.np=mxGetNumberOfElements(field(c,"origins"));m.ramp=mxGetScalar(field(c,"transition_s"));
 m.nativeEnd=mxGetScalar(field(c,"native_end_s"));m.returnEnd=mxGetScalar(field(c,"return_end_s"));
 size_t ns=mxGetNumberOfElements(prhs[1]);if(ns<29)mexErrMsgIdAndTxt("FOURWAY:State","State needs 29 elements.");
 std::vector<double>s(mxGetDoubles(prhs[1]),mxGetDoubles(prhs[1])+ns);double end=mxGetScalar(prhs[2]);
 const double*tr=mxGetDoubles(prhs[3]);size_t nt=mxGetM(prhs[3]),ti=0;
 const double*qt=nrhs>4?mxGetDoubles(prhs[4]):nullptr;size_t nq=nrhs>4?mxGetNumberOfElements(prhs[4]):0,qi=0;
 double t=s[0],driver=s[4],driverSlope=s[5],rampEnd=s[6];int ia=(int)s[7],ib=(int)s[8],ra=(int)s[9];bool failed=s[13]!=0;size_t pulse=(size_t)s[14],knot=(size_t)s[15];int ideal=(int)s[16];
 Vec y=modal(m,&s[1]);std::vector<Event>events;std::vector<Change>changes;std::vector<Row>boundary,query;
 auto logBoundary=[&](int kind,double dv){auto x=physical(m,y);boundary.push_back({t,(double)kind,x[0],x[1],x[2],driver,dv});};
 while(true){
   // Apply exact source/driver boundary changes at this timestamp first.
   if(driverSlope!=0&&t>=rampEnd){driver=2*ia-1;driverSlope=0;logBoundary(2,0);}
   while(pulse<m.np&&t>=m.orig[pulse]+m.kt[m.nk-1]){if(m.returnEnd==m.kt[m.nk-1])logBoundary(6,0);logBoundary(4,0);++pulse;knot=0;}
   if(pulse<m.np&&t>=m.orig[pulse]){
      if(knot==0&&std::abs(t-m.orig[pulse])<1e-15)logBoundary(3,m.dv[0]);
      while(knot+1<m.nk&&t>=m.orig[pulse]+m.kt[knot+1]){++knot;if(m.kt[knot]==m.nativeEnd)logBoundary(5,knot<m.nk-1?m.dv[knot]:0);if(m.kt[knot]==m.returnEnd)logBoundary(6,knot<m.nk-1?m.dv[knot]:0);}
   }
   while(ti<nt&&tr[ti]<=t){int a=(int)tr[ti+nt],b=(int)tr[ti+2*nt];ideal+=increment(ia,ib,a,b);if(a!=ia){driverSlope=((2*a-1)-driver)/m.ramp;rampEnd=t+m.ramp;ia=a;logBoundary(1,0);}if(b!=ib){changes.push_back({tr[ti],0,b,false});ib=b;}++ti;}
   while(qi<nq&&qt[qi]<=t){auto x=physical(m,y);query.push_back({qt[qi],x[0],x[1],x[2]});++qi;}
   if(t>=end)break;
   double next=end,dv=0;
   if(ti<nt)next=std::min(next,tr[ti]);if(driverSlope!=0)next=std::min(next,rampEnd);if(qi<nq)next=std::min(next,qt[qi]);
   if(pulse<m.np){if(t<m.orig[pulse])next=std::min(next,m.orig[pulse]);else{next=std::min(next,m.orig[pulse]+m.kt[knot+1]);dv=m.dv[knot];}}
   double dt=next-t;if(!(dt>0))mexErrMsgIdAndTxt("FOURWAY:TimeProgress","Nonpositive exact interval.");
   Flow f;f.m=&m;for(int i=0;i<3;++i){Z f0=m.F[i][0]+m.F[i][1]*driver+m.F[i][2]*dv,f1=m.F[i][1]*driverSlope;f.c1[i]=-f1/m.l[i];f.c0[i]=(f.c1[i]-f0)/m.l[i];f.z[i]=y[i]-f.c0[i];}
   std::vector<Event>segment;
   for(int kind=1;kind<=2;++kind){for(double sign:{-1.0,1.0}){double level=sign*(kind==1?.2:7.0);Scalar sc=scalar(f,kind,level);std::vector<std::pair<double,int>>r;roots(sc,0,dt,r);for(auto root:r){auto x=physical(m,value(f,root.first));segment.push_back({t+root.first,kind,level,root.second,x,ra});}}}
   std::sort(segment.begin(),segment.end(),[](const Event&a,const Event&b){return a.t<b.t;});
   for(auto&e:segment){int history=20+2*(2*(e.kind-1)+(e.threshold>0?1:0));if(std::abs(e.t-s[history])<=1e-15&&e.dir==(int)s[history+1])continue;s[history]=e.t;s[history+1]=e.dir;
     if(e.kind==2&&((e.threshold>0&&e.dir>0)||(e.threshold<0&&e.dir<0)))failed=true;
     if(!failed&&e.kind==1){int newA=ra;if(e.threshold>0&&e.dir>0)newA=1;if(e.threshold<0&&e.dir<0)newA=0;if(newA!=ra){ra=newA;changes.push_back({e.t,ra,0,true});}}
     e.a=ra;events.push_back(e);
   }
   // Track true within-interval common-mode extrema, not only saved samples.
   Scalar cm=scalar(f,2);s[17]=std::max(s[17],std::max(std::abs(val(cm,0)),std::abs(val(cm,dt))));
   Scalar deriv=cm;deriv.c0=cm.c1;deriv.c1=0;for(int i=0;i<3;++i)deriv.a[i]*=m.l[i];
   double transientAmplitude=0;for(auto a:cm.a)transientAmplitude+=std::abs(a);
   std::vector<std::pair<double,int>>extrema;if(transientAmplitude>1e-10)roots(deriv,0,dt,extrema,0,false);for(auto e:extrema)s[17]=std::max(s[17],std::abs(val(cm,e.first)));
   if(s[17]>7+1e-12)failed=true;
   Scalar df=scalar(f,1);s[18]=std::max(s[18],std::max(std::abs(val(df,0)),std::abs(val(df,dt))));
   y=value(f,dt);driver+=driverSlope*dt;t=next;s[19]+=1;
 }
 // The ideal B bit and receiver A events are decoded jointly within 1 ps.
 // All changes are processed before the packet at end, including invalids.
 std::stable_sort(changes.begin(),changes.end(),[](const Change&a,const Change&b){return a.t<b.t;});
 int pa=(int)s[11],pb=(int)s[12],count=(int)s[10];std::vector<Row>dec;
 if(!changes.empty()&&s[28]>=0&&changes[0].t-s[28]<=JOINT)
   mexErrMsgIdAndTxt("FOURWAY:CrossPacketJointAmbiguity","A new A/B event is within 1 ps of an event already sampled in a preceding call. Joint grouping would require future information or retrospective count repair. Reject this alignment and retain diagnostics.");
 for(size_t i=0;i<changes.size();){double when=changes[i].t;int a=pa,b=pb;size_t j=i;while(j<changes.size()&&changes[j].t-when<=JOINT){if(changes[j].isa)a=changes[j].a;else b=changes[j].b;++j;}if(a!=pa||b!=pb){bool inv=(a!=pa&&b!=pb);int inc=inv?0:increment(pa,pb,a,b);count+=inc;dec.push_back({when,(double)a,(double)b,(double)inc,(double)count,(double)inv,(double)pa,(double)pb});pa=a;pb=b;s[28]=when;}i=j;}
 auto x=physical(m,y);s[0]=t;for(int i=0;i<3;++i)s[1+i]=x[i];s[4]=driver;s[5]=driverSlope;s[6]=rampEnd;s[7]=ia;s[8]=ib;s[9]=ra;s[10]=count;s[11]=pa;s[12]=pb;s[13]=failed;s[14]=(double)pulse;s[15]=(double)knot;s[16]=ideal;
 plhs[0]=mxCreateDoubleMatrix(ns,1,mxREAL);std::copy(s.begin(),s.end(),mxGetDoubles(plhs[0]));std::vector<Row>er;for(auto&e:events)er.push_back({e.t,(double)e.kind,e.threshold,(double)e.dir,e.x[0],e.x[1],e.x[2],(double)e.a});
 plhs[1]=rows(er,8);plhs[2]=rows(dec,8);plhs[3]=rows(boundary,7);if(nlhs>4)plhs[4]=rows(query,4);
}
