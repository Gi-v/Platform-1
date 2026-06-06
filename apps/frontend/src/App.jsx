import { useState, useEffect, useRef } from "react"

const C = {
  void:"#020408", deep:"#060d14", surface:"#0a1520", raised:"#0f1e2e",
  border:"#1a3048", border2:"#254060", tx:"#d4e8f0", tx2:"#7a9bb5", tx3:"#3d6070",
  acid:"#00ff9d", cyan:"#00c8ff", orange:"#ff6b2b", red:"#ff3355", yellow:"#ffd700",
}

const css = `
  @import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;500;600;700&family=Fira+Code:wght@300;400;500&display=swap');
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:${C.void};color:${C.tx};font-family:'Space Grotesk',sans-serif;overflow-x:hidden}
  ::-webkit-scrollbar{width:4px} ::-webkit-scrollbar-thumb{background:${C.border2};border-radius:2px}
  @keyframes fadeUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
  @keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.3;transform:scale(.8)}}
  @keyframes spin{to{transform:rotate(360deg)}}
  @keyframes scanline{0%{transform:translateY(-100%)}100%{transform:translateY(100vh)}}
  .fu{animation:fadeUp .5s ease both}
  .d1{animation-delay:.1s}.d2{animation-delay:.2s}.d3{animation-delay:.3s}.d4{animation-delay:.4s}
`

// ── Tiny components ────────────────────────────────────────────────────────────
const Blink = () => (
  <span style={{display:'inline-block',width:7,height:7,borderRadius:'50%',
    background:C.acid,boxShadow:`0 0 8px ${C.acid}`,
    animation:'pulse 2s infinite',flexShrink:0}} />
)

const Badge = ({env}) => {
  const map = {prod:[C.acid,'rgba(0,255,157,.08)'],staging:[C.yellow,'rgba(255,215,0,.08)'],dev:[C.cyan,'rgba(0,200,255,.08)']}
  const [col,bg] = map[env]||map.dev
  return <span style={{padding:'2px 8px',borderRadius:3,fontSize:10,fontWeight:600,
    fontFamily:"'Fira Code',monospace",border:`1px solid ${col}44`,background:bg,color:col,
    letterSpacing:.5}}>{env}</span>
}

const StatusDot = ({status}) => {
  const map = {healthy:C.acid,degraded:C.red,canary:C.yellow}
  const col = map[status]||C.tx3
  return <span style={{display:'flex',alignItems:'center',gap:5,fontSize:11,fontFamily:"'Fira Code',monospace"}}>
    <span style={{width:7,height:7,borderRadius:'50%',background:col,
      boxShadow:`0 0 8px ${col}`,flexShrink:0,
      animation:status==='canary'?'pulse 1.5s infinite':undefined}} />
    {status}
  </span>
}

const MiniBar = ({val}) => {
  const col = val>80?C.red:val>60?C.yellow:C.acid
  return <span style={{display:'inline-flex',alignItems:'center',gap:6}}>
    <span style={{display:'inline-block',width:60,height:3,borderRadius:2,
      background:C.raised,overflow:'hidden',verticalAlign:'middle'}}>
      <span style={{display:'block',height:'100%',width:`${val}%`,
        background:col,borderRadius:2,transition:'width 1s ease'}} />
    </span>
    <span style={{fontSize:11,color:C.tx3,fontFamily:"'Fira Code',monospace"}}>{val}%</span>
  </span>
}

// ── Particle canvas background ────────────────────────────────────────────────
function ParticleBg() {
  const ref = useRef()
  useEffect(() => {
    const c = ref.current
    const ctx = c.getContext('2d')
    let W,H,pts=[],raf
    const resize = () => { W=c.width=innerWidth; H=c.height=innerHeight }
    resize()
    window.addEventListener('resize',resize)
    for(let i=0;i<70;i++) pts.push({
      x:Math.random()*W,y:Math.random()*H,
      vx:(Math.random()-.5)*.3,vy:(Math.random()-.5)*.3,
      r:Math.random()*1.5+.5,
      col:Math.random()>.5?'rgba(0,255,157,':'rgba(0,200,255,'
    })
    const draw = () => {
      ctx.clearRect(0,0,W,H)
      pts.forEach(p => {
        p.x+=p.vx; p.y+=p.vy
        if(p.x<0)p.x=W; if(p.x>W)p.x=0
        if(p.y<0)p.y=H; if(p.y>H)p.y=0
        ctx.beginPath(); ctx.arc(p.x,p.y,p.r,0,Math.PI*2)
        ctx.fillStyle=p.col+'.5)'; ctx.fill()
      })
      pts.forEach((a,i) => pts.slice(i+1).forEach(b => {
        const d=Math.hypot(a.x-b.x,a.y-b.y)
        if(d<110) {
          ctx.beginPath(); ctx.moveTo(a.x,a.y); ctx.lineTo(b.x,b.y)
          ctx.strokeStyle=`rgba(0,255,157,${.1*(1-d/110)})`
          ctx.lineWidth=.5; ctx.stroke()
        }
      }))
      raf=requestAnimationFrame(draw)
    }
    draw()
    return () => { cancelAnimationFrame(raf); window.removeEventListener('resize',resize) }
  },[])
  return <canvas ref={ref} style={{position:'fixed',inset:0,zIndex:0,opacity:.5,pointerEvents:'none'}} />
}

// ── Mock data ─────────────────────────────────────────────────────────────────
const MOCK_SVCS = [
  {name:'payment-api',team:'payments',env:'prod',status:'healthy',version:'v2.4.1',cpu:42,mem:61},
  {name:'user-service',team:'platform',env:'prod',status:'healthy',version:'v1.9.0',cpu:28,mem:44},
  {name:'notification-svc',team:'comms',env:'staging',status:'canary',version:'v3.1.0',cpu:55,mem:72},
  {name:'inventory-api',team:'fulfil',env:'prod',status:'healthy',version:'v1.2.3',cpu:19,mem:38},
  {name:'ml-inference',team:'ai',env:'prod',status:'degraded',version:'v0.8.2',cpu:88,mem:91},
  {name:'auth-gateway',team:'platform',env:'prod',status:'healthy',version:'v4.2.0',cpu:35,mem:48},
]
const MOCK_DORA = {
  deployFrequency:{value:14.2,unit:'/day',trend:8},
  leadTime:{value:23,unit:'min',trend:-12},
  changeFailureRate:{value:2.1,unit:'%',trend:-0.4},
  mttr:{value:18,unit:'min',trend:-22},
}

// ── Hooks ─────────────────────────────────────────────────────────────────────
function useAPI(path, fallback) {
  const [data,setData] = useState(fallback)
  useEffect(() => {
    fetch(path,{signal:AbortSignal.timeout(3000)})
      .then(r=>r.json()).then(setData).catch(()=>{})
  },[path])
  return data
}

// ── Main App ──────────────────────────────────────────────────────────────────
export default function App() {
  const [tab,setTab] = useState('services')
  const [health,setHealth] = useState('checking')
  const svcs  = useAPI('/api/services',  MOCK_SVCS)
  const dora  = useAPI('/api/dora',      MOCK_DORA)
  const cluster = useAPI('/api/cluster', {nodes:{total:3,ready:3},pods:{running:87,failed:0},namespaces:12,deployments:{total:24}})

  useEffect(() => {
    fetch('/healthz').then(()=>setHealth('connected')).catch(()=>setHealth('offline'))
  },[])

  const S = { // shared styles object
    page:   {position:'relative',zIndex:1,minHeight:'100vh'},
    header: {position:'sticky',top:0,zIndex:100,background:'rgba(2,4,8,.85)',
      backdropFilter:'blur(20px)',borderBottom:`1px solid ${C.border}`,
      display:'flex',alignItems:'center',padding:'0 28px',height:56,gap:20},
    logoText: {fontWeight:700,fontSize:16,color:'#fff',letterSpacing:'-.5px',textDecoration:'none'},
    navA: (active) => ({padding:'0 14px',height:56,display:'flex',alignItems:'center',
      color:active?C.acid:C.tx3,fontSize:12,fontWeight:500,letterSpacing:.5,
      textTransform:'uppercase',cursor:'pointer',borderBottom:`2px solid ${active?C.acid:'transparent'}`,
      transition:'.2s',textDecoration:'none'}),
    chip: {display:'flex',alignItems:'center',gap:6,padding:'4px 12px',
      border:`1px solid ${C.acid}33`,borderRadius:20,fontSize:11,
      fontFamily:"'Fira Code',monospace",color:C.acid,background:'rgba(0,255,157,.05)'},
    btnAcid: {padding:'7px 16px',borderRadius:6,fontFamily:"'Fira Code',monospace",fontSize:11,
      fontWeight:700,cursor:'pointer',border:`1px solid ${C.acid}`,
      background:C.acid,color:'#000',textDecoration:'none',display:'inline-flex',
      alignItems:'center',gap:6,transition:'all .2s'},
    btnGhost: {padding:'7px 16px',borderRadius:6,fontFamily:"'Fira Code',monospace",fontSize:11,
      cursor:'pointer',border:`1px solid ${C.border2}`,background:'transparent',
      color:C.tx2,textDecoration:'none',display:'inline-flex',alignItems:'center',gap:6},
    card: {background:C.surface,border:`1px solid ${C.border}`,borderRadius:10,padding:20},
    secTitle: {fontSize:10,letterSpacing:3,textTransform:'uppercase',color:C.tx3,
      fontFamily:"'Fira Code',monospace",display:'flex',alignItems:'center',gap:8},
    th: {fontSize:10,letterSpacing:1.5,textTransform:'uppercase',color:C.tx3,
      padding:'8px 12px',textAlign:'left',borderBottom:`1px solid ${C.border}`,
      fontFamily:"'Fira Code',monospace",fontWeight:400},
    td: {padding:'11px 12px',borderBottom:`1px solid ${C.border}44`,verticalAlign:'middle'},
  }

  const StatCard = ({label,value,sub,subColor}) => (
    <div style={{background:C.deep,padding:'20px 24px',borderRight:`1px solid ${C.border}`,flex:1,
      position:'relative',overflow:'hidden',transition:'.2s',cursor:'default'}}>
      <div style={{fontSize:10,letterSpacing:2,textTransform:'uppercase',color:C.tx3,
        fontFamily:"'Fira Code',monospace",marginBottom:8}}>{label}</div>
      <div style={{fontSize:'2rem',fontWeight:700,color:'#fff',letterSpacing:-1,lineHeight:1}}>{value}</div>
      <div style={{fontSize:11,color:subColor||C.tx3,fontFamily:"'Fira Code',monospace",marginTop:4}}>{sub}</div>
    </div>
  )

  const DoraCard = ({label,value,unit,trend,goodDir}) => {
    const good = (goodDir==='up'&&trend>0)||(goodDir==='down'&&trend<0)
    return <div style={{background:C.surface,padding:16,transition:'.2s',cursor:'default'}}>
      <div style={{fontSize:10,letterSpacing:1.5,textTransform:'uppercase',color:C.tx3,
        fontFamily:"'Fira Code',monospace",marginBottom:8}}>{label}</div>
      <div style={{fontSize:'1.5rem',fontWeight:700,color:'#fff',letterSpacing:-1,lineHeight:1}}>
        {value}<span style={{fontSize:11,color:C.tx3,marginLeft:3}}>{unit}</span>
      </div>
      <div style={{fontSize:11,fontFamily:"'Fira Code',monospace",marginTop:4,
        color:good?C.acid:C.red}}>{trend>0?'↑':'↓'} {Math.abs(trend)}</div>
    </div>
  }

  return (
    <>
      <style>{css}</style>
      <ParticleBg />

      <div style={S.page}>
        {/* Header */}
        <header style={S.header}>
          <a href="/" style={S.logoText}>
            platform<span style={{color:C.acid}}>-one</span>
          </a>
          <nav style={{flex:1,display:'flex',gap:2}}>
            {['services','deploy','observe'].map(t=>(
              <span key={t} style={S.navA(tab===t)} onClick={()=>setTab(t)}>{t}</span>
            ))}
            <a href="http://localhost:8090" target="_blank" rel="noopener" style={S.navA(false)}>ArgoCD ↗</a>
            <a href="http://localhost:3000" target="_blank" rel="noopener" style={S.navA(false)}>Grafana ↗</a>
          </nav>
          <div style={{display:'flex',alignItems:'center',gap:10,marginLeft:'auto'}}>
            <span style={S.chip}><Blink /> <span style={{fontSize:10}}>
              {health==='connected'?'cluster connected':health==='offline'?'offline':'checking…'}
            </span></span>
            <a href="http://localhost:8080" target="_blank" rel="noopener" style={S.btnAcid}>
              ⊕ Platform Portal
            </a>
          </div>
        </header>

        {/* Hero */}
        <section className="fu" style={{padding:'72px 32px 48px',position:'relative',overflow:'hidden',
          borderBottom:`1px solid ${C.border}`}}>
          <div style={{maxWidth:1200,margin:'0 auto'}}>
            <div className="fu" style={{fontSize:11,letterSpacing:3,textTransform:'uppercase',
              color:C.acid,marginBottom:16,display:'flex',alignItems:'center',gap:10,
              fontFamily:"'Fira Code',monospace"}}>
              <span style={{width:28,height:1,background:C.acid,display:'inline-block'}}/>
              Deployed via platform-one
            </div>
            <h1 className="fu d1" style={{fontSize:'clamp(2.5rem,5vw,4.5rem)',fontWeight:700,
              letterSpacing:-3,lineHeight:.95,color:'#fff',marginBottom:20}}>
              My Application<br/>
              <span style={{background:`linear-gradient(90deg,${C.acid},${C.cyan})`,
                WebkitBackgroundClip:'text',WebkitTextFillColor:'transparent',
                backgroundClip:'text'}}>is live.</span>
            </h1>
            <p className="fu d2" style={{color:C.tx2,fontSize:15,lineHeight:1.7,
              maxWidth:500,marginBottom:28}}>
              This frontend is auto-deployed via ArgoCD, protected by Kyverno policies,
              instrumented with OpenTelemetry, and backed by Vault secrets.
            </p>
            <div className="fu d3" style={{display:'flex',gap:10,flexWrap:'wrap'}}>
              <a href="http://localhost:8090" target="_blank" rel="noopener" style={S.btnAcid}>
                View in ArgoCD →
              </a>
              <a href="http://localhost:3000" target="_blank" rel="noopener" style={S.btnGhost}>
                Grafana Dashboard
              </a>
              <a href="http://localhost:8080" target="_blank" rel="noopener" style={S.btnGhost}>
                Platform Portal
              </a>
            </div>
          </div>
        </section>

        {/* Stats strip */}
        <div className="fu d1" style={{display:'flex',background:C.border,
          borderBottom:`1px solid ${C.border}`}}>
          <StatCard label="Services"    value={cluster.deployments?.total||'—'} sub={`${cluster.namespaces} namespaces`} />
          <StatCard label="Pods"        value={cluster.pods?.running||'—'} sub={`${cluster.pods?.failed||0} failing`} subColor={cluster.pods?.failed>0?C.red:C.tx3} />
          <StatCard label="Nodes"       value={cluster.nodes?.ready||'—'} sub={`of ${cluster.nodes?.total||'—'} ready`} subColor={C.acid} />
          <StatCard label="Deploy Freq" value={dora.deployFrequency?.value||'—'} sub="per day" subColor={C.acid} />
          <StatCard label="Lead Time"   value={`${dora.leadTime?.value||'—'}m`} sub="to production" subColor={C.acid} />
          <StatCard label="Fail Rate"   value={`${dora.changeFailureRate?.value||'—'}%`} sub="last 7 days" />
        </div>

        {/* Main content */}
        <div style={{display:'grid',gridTemplateColumns:'1fr 320px',background:C.border,minHeight:'60vh'}}>
          <div style={{background:C.deep,padding:24,borderRight:`1px solid ${C.border}`}}>

            {/* Services table */}
            <div className="fu d2" style={{marginBottom:24}}>
              <div style={{...S.secTitle,marginBottom:16}}>
                <span style={{width:3,height:14,background:C.acid,borderRadius:2,
                  boxShadow:`0 0 8px ${C.acid}`}}/>
                Service Catalog
              </div>
              <table style={{width:'100%',borderCollapse:'collapse'}}>
                <thead><tr>
                  {['Service','Env','Status','Version','CPU','Memory'].map(h=>(
                    <th key={h} style={S.th}>{h}</th>
                  ))}
                </tr></thead>
                <tbody>
                  {svcs.map((s,i)=>(
                    <tr key={i} style={{cursor:'pointer',transition:'.15s'}}
                      onMouseEnter={e=>e.currentTarget.style.background='rgba(255,255,255,.02)'}
                      onMouseLeave={e=>e.currentTarget.style.background='transparent'}
                      onClick={()=>window.open(`http://localhost:8090/applications/${s.name}`,'_blank')}>
                      <td style={S.td}>
                        <div style={{fontWeight:600,fontSize:13,color:'#fff'}}>{s.name}</div>
                        <div style={{fontSize:11,color:C.tx3,fontFamily:"'Fira Code',monospace"}}>{s.team}</div>
                      </td>
                      <td style={S.td}><Badge env={s.env}/></td>
                      <td style={S.td}><StatusDot status={s.status}/></td>
                      <td style={{...S.td,color:C.tx3,fontFamily:"'Fira Code',monospace",fontSize:12}}>{s.version}</td>
                      <td style={S.td}><MiniBar val={s.cpu}/></td>
                      <td style={S.td}><MiniBar val={s.mem}/></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* App info */}
            <div className="fu d3" style={{...S.card,borderLeft:`3px solid ${C.acid}`}}>
              <div style={{...S.secTitle,marginBottom:16}}>
                <span style={{width:3,height:14,background:C.acid,borderRadius:2}}/>
                Platform Wiring
              </div>
              <div style={{display:'grid',gridTemplateColumns:'repeat(2,1fr)',gap:12}}>
                {[
                  {label:'GitOps',     value:'ArgoCD auto-sync',         col:C.acid},
                  {label:'Policies',   value:'Kyverno enforced',          col:C.yellow},
                  {label:'Telemetry',  value:'OTel → Tempo + Loki',       col:C.cyan},
                  {label:'Secrets',    value:'Vault + ESO',               col:C.orange},
                  {label:'Delivery',   value:'Argo Rollouts canary',      col:C.purple||'#a855f7'},
                  {label:'Security',   value:'cosign image signing',      col:C.acid},
                ].map(({label,value,col})=>(
                  <div key={label} style={{background:C.raised,border:`1px solid ${C.border}`,
                    borderRadius:8,padding:'12px 14px'}}>
                    <div style={{fontSize:10,letterSpacing:1.5,textTransform:'uppercase',
                      color:C.tx3,fontFamily:"'Fira Code',monospace",marginBottom:4}}>{label}</div>
                    <div style={{fontSize:13,fontWeight:600,color:col}}>{value}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Sidebar */}
          <div style={{background:C.deep,padding:24}}>
            {/* DORA */}
            <div className="fu d2" style={{marginBottom:20}}>
              <div style={{...S.secTitle,marginBottom:16}}>
                <span style={{width:3,height:14,background:C.acid,borderRadius:2,boxShadow:`0 0 8px ${C.acid}`}}/>
                DORA Metrics
              </div>
              <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:1,
                background:C.border,border:`1px solid ${C.border}`,borderRadius:10,overflow:'hidden'}}>
                <DoraCard label="Deploy Freq" value={dora.deployFrequency?.value}  unit="/day" trend={dora.deployFrequency?.trend}  goodDir="up"   />
                <DoraCard label="Lead Time"   value={`${dora.leadTime?.value}m`}   unit=""     trend={dora.leadTime?.trend}          goodDir="down" />
                <DoraCard label="Fail Rate"   value={`${dora.changeFailureRate?.value}%`} unit="" trend={dora.changeFailureRate?.trend} goodDir="down" />
                <DoraCard label="MTTR"        value={`${dora.mttr?.value}m`}       unit=""     trend={dora.mttr?.trend}              goodDir="down" />
              </div>
            </div>

            {/* Quick links */}
            <div className="fu d3">
              <div style={{...S.secTitle,marginBottom:14}}>
                <span style={{width:3,height:14,background:C.acid,borderRadius:2}}/>
                Quick Links
              </div>
              {[
                {label:'Platform Portal',  url:'http://localhost:8080', col:C.acid},
                {label:'ArgoCD',           url:'http://localhost:8090', col:C.acid},
                {label:'Grafana',          url:'http://localhost:3000', col:C.yellow},
                {label:'Prometheus',       url:'http://localhost:9090', col:C.orange},
                {label:'Vault',            url:'http://localhost:8200', col:C.purple||'#a855f7'},
              ].map(({label,url,col})=>(
                <a key={label} href={url} target="_blank" rel="noopener"
                  style={{display:'flex',alignItems:'center',justifyContent:'space-between',
                    padding:'10px 12px',background:C.surface,border:`1px solid ${C.border}`,
                    borderRadius:7,marginBottom:6,textDecoration:'none',transition:'.2s',
                    cursor:'pointer'}}
                  onMouseEnter={e=>{e.currentTarget.style.borderColor=col;e.currentTarget.style.transform='translateX(3px)'}}
                  onMouseLeave={e=>{e.currentTarget.style.borderColor=C.border;e.currentTarget.style.transform='none'}}>
                  <span style={{fontSize:13,fontWeight:500,color:'#fff'}}>{label}</span>
                  <span style={{fontSize:12,color:col,fontFamily:"'Fira Code',monospace"}}>↗</span>
                </a>
              ))}
            </div>
          </div>
        </div>

        {/* Footer */}
        <footer style={{borderTop:`1px solid ${C.border}`,padding:'14px 28px',
          display:'flex',alignItems:'center',justifyContent:'space-between',
          fontSize:11,color:C.tx3,fontFamily:"'Fira Code',monospace",
          background:C.void,flexWrap:'wrap',gap:8,position:'relative',zIndex:2}}>
          <span>platform-one · frontend · {new Date().toUTCString().replace(' GMT',' UTC')}</span>
          <span style={{display:'flex',alignItems:'center',gap:6}}>
            <Blink/>
            <span style={{color:health===('connected')?C.acid:C.red}}>{health}</span>
          </span>
        </footer>
      </div>
    </>
  )
}
