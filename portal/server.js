/**
 * Platform One Portal — zero-dependency Node.js HTTP server
 * Uses only built-in modules: http, https, fs, path, url
 * Works in k8s with node:20-alpine, no npm install required.
 */
'use strict';

const http  = require('http');
const https = require('https');
const fs    = require('fs');
const path  = require('path');
const url   = require('url');

const PORT    = parseInt(process.env.PORT || '3030', 10);
const PUBLIC  = path.join(__dirname, 'public');

// ── Kubernetes in-cluster client ─────────────────────────────────────────────
const K8S_HOST   = process.env.KUBERNETES_SERVICE_HOST;
const K8S_PORT   = process.env.KUBERNETES_SERVICE_PORT || '443';
const TOKEN_FILE = '/var/run/secrets/kubernetes.io/serviceaccount/token';
const CA_FILE    = '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt';

function inCluster() {
  return !!K8S_HOST && fs.existsSync(TOKEN_FILE);
}

function k8sGet(apiPath) {
  return new Promise((resolve, reject) => {
    const token = fs.readFileSync(TOKEN_FILE, 'utf8').trim();
    const ca    = fs.readFileSync(CA_FILE);
    const req   = https.request(
      { hostname: K8S_HOST, port: K8S_PORT, path: apiPath,
        method: 'GET', ca, headers: { Authorization: `Bearer ${token}` }, timeout: 4000 },
      (res) => {
        let data = '';
        res.on('data', c => { data += c; });
        res.on('end',  () => { try { resolve(JSON.parse(data)); } catch(e) { reject(e); } });
      }
    );
    req.on('error',   reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    req.end();
  });
}

// ── MIME types ────────────────────────────────────────────────────────────────
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript',
  '.css':  'text/css',
  '.json': 'application/json',
  '.png':  'image/png',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
};

// ── Static file server ────────────────────────────────────────────────────────
function serveStatic(res, filePath) {
  try {
    const data = fs.readFileSync(filePath);
    const ext  = path.extname(filePath);
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(data);
  } catch {
    const index = fs.readFileSync(path.join(PUBLIC, 'index.html'));
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(index);
  }
}

function json(res, data, status) {
  const body = JSON.stringify(data);
  res.writeHead(status || 200, { 'Content-Type': 'application/json',
                                  'Access-Control-Allow-Origin': '*' });
  res.end(body);
}

// ── Mock data ─────────────────────────────────────────────────────────────────
const MOCK = {
  cluster: { nodes:{total:3,ready:3}, namespaces:12,
             deployments:{total:24,healthy:23,degraded:1}, pods:{running:87,pending:2,failed:0} },
  services: [
    {name:'payment-api',      team:'payments',env:'prod',   status:'healthy', version:'v2.4.1',replicas:3,cpu:42,mem:61},
    {name:'user-service',     team:'platform',env:'prod',   status:'healthy', version:'v1.9.0',replicas:2,cpu:28,mem:44},
    {name:'notification-svc', team:'comms',   env:'staging',status:'canary',  version:'v3.1.0',replicas:4,cpu:55,mem:72},
    {name:'inventory-api',    team:'fulfil',  env:'prod',   status:'healthy', version:'v1.2.3',replicas:2,cpu:19,mem:38},
    {name:'ml-inference',     team:'ai',      env:'prod',   status:'degraded',version:'v0.8.2',replicas:1,cpu:88,mem:91},
    {name:'event-consumer',   team:'data',    env:'prod',   status:'healthy', version:'v2.0.0',replicas:3,cpu:31,mem:55},
    {name:'analytics-worker', team:'data',    env:'dev',    status:'healthy', version:'v1.0.0',replicas:1,cpu:12,mem:29},
    {name:'auth-gateway',     team:'platform',env:'prod',   status:'healthy', version:'v4.2.0',replicas:5,cpu:35,mem:48},
  ],
  deployments: [
    {id:1,service:'payment-api',     env:'prod',   status:'success',duration:'3m 12s',sha:'a3f9c1d',ago:Date.now()-1800000},
    {id:2,service:'notification-svc',env:'staging',status:'running',duration:'1m 44s',sha:'e7b2a90',ago:Date.now()-90000},
    {id:3,service:'user-service',    env:'prod',   status:'success',duration:'2m 58s',sha:'c1d4e2f',ago:Date.now()-7200000},
    {id:4,service:'auth-gateway',    env:'prod',   status:'success',duration:'4m 05s',sha:'9f3b7e1',ago:Date.now()-14400000},
    {id:5,service:'ml-inference',    env:'prod',   status:'failed', duration:'1m 22s',sha:'b0a8d3c',ago:Date.now()-21600000},
  ],
  dora: {
    deployFrequency:{value:14.2,unit:'deploys/day',trend:8},
    leadTime:{value:23,unit:'min',trend:-12},
    changeFailureRate:{value:2.1,unit:'%',trend:-0.4},
    mttr:{value:18,unit:'min',trend:-22},
  },
};

const SYSTEM_NS = new Set(['kube-system','kube-public','kube-node-lease','argocd',
  'crossplane-system','kyverno','cert-manager','external-secrets',
  'ingress-nginx','monitoring','vault','argo-rollouts']);

// ── API handlers ──────────────────────────────────────────────────────────────
async function handleAPI(pathname, res) {
  if (pathname === '/healthz') {
    return json(res, { status:'ok', inCluster:inCluster(), version:'1.0.0' });
  }

  if (pathname === '/api/cluster') {
    if (!inCluster()) return json(res, MOCK.cluster);
    try {
      const [nodes, pods, ns, deps] = await Promise.all([
        k8sGet('/api/v1/nodes'), k8sGet('/api/v1/pods'),
        k8sGet('/api/v1/namespaces'), k8sGet('/apis/apps/v1/deployments'),
      ]);
      const readyNodes  = nodes.items.filter(n =>
        n.status.conditions?.some(c => c.type==='Ready' && c.status==='True')).length;
      const healthyDeps = deps.items.filter(d =>
        (d.status.availableReplicas||0) >= (d.spec.replicas||1)).length;
      return json(res, {
        nodes: {total:nodes.items.length, ready:readyNodes},
        namespaces: ns.items.length,
        deployments: {total:deps.items.length, healthy:healthyDeps, degraded:deps.items.length-healthyDeps},
        pods: {
          running: pods.items.filter(p=>p.status.phase==='Running').length,
          pending: pods.items.filter(p=>p.status.phase==='Pending').length,
          failed:  pods.items.filter(p=>p.status.phase==='Failed').length,
        },
      });
    } catch(e) { console.error('/api/cluster:', e.message); return json(res, MOCK.cluster); }
  }

  if (pathname === '/api/services') {
    if (!inCluster()) return json(res, MOCK.services);
    try {
      const deps = await k8sGet('/apis/apps/v1/deployments');
      const svcs = deps.items.filter(d => !SYSTEM_NS.has(d.metadata.namespace)).map(d => ({
        name:     d.metadata.name,
        team:     d.metadata.labels?.team || d.metadata.namespace,
        env:      d.metadata.labels?.environment || 'prod',
        status:   (d.status.availableReplicas||0)>=(d.spec.replicas||1) ? 'healthy' : 'degraded',
        version:  d.metadata.labels?.['app.kubernetes.io/version'] || 'latest',
        replicas: d.spec.replicas || 1,
        cpu: Math.floor(Math.random()*60)+10,
        mem: Math.floor(Math.random()*50)+20,
      }));
      return json(res, svcs.length > 0 ? svcs : MOCK.services);
    } catch(e) { console.error('/api/services:', e.message); return json(res, MOCK.services); }
  }

  if (pathname === '/api/deployments') {
    if (!inCluster()) return json(res, MOCK.deployments);
    try {
      const apps = await k8sGet('/apis/argoproj.io/v1alpha1/applications');
      if (apps.items?.length > 0) {
        return json(res, apps.items.slice(0,8).map((a,i) => ({
          id: i+1,
          service: a.metadata.name,
          env: a.spec.destination.namespace || 'default',
          status: a.status?.sync?.status==='Synced' ? 'success' :
                  a.status?.sync?.status==='OutOfSync' ? 'running' : 'failed',
          duration: '—',
          sha: (a.status?.sync?.revision||'unknown').slice(0,7),
          ago: Date.now()-(i*1800000),
        })));
      }
    } catch(e) { console.error('/api/deployments:', e.message); }
    return json(res, MOCK.deployments);
  }

  if (pathname === '/api/dora') {
    return json(res, MOCK.dora);
  }

  json(res, {error:'not found'}, 404);
}

// ── HTTP server ───────────────────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {
  const { pathname } = url.parse(req.url || '/');

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Methods':'GET'});
    return res.end();
  }

  if (pathname === '/healthz' || (pathname && pathname.startsWith('/api/'))) {
    try { await handleAPI(pathname, res); }
    catch(e) { json(res, {error: e.message}, 500); }
    return;
  }

  // Static files
  const filePath = path.join(PUBLIC, pathname === '/' ? 'index.html' : pathname);
  serveStatic(res, filePath);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Platform One Portal → http://localhost:${PORT}  inCluster=${inCluster()}`);
});

server.on('error', (e) => { console.error('Server error:', e); process.exit(1); });
