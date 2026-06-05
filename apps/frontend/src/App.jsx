import React, { useState, useEffect } from 'react'

export default function App() {
  const [status, setStatus] = useState('loading')

  useEffect(() => {
    fetch('/api/healthz')
      .then(r => r.json())
      .then(() => setStatus('connected'))
      .catch(() => setStatus('offline'))
  }, [])

  return (
    <div style={{ fontFamily: 'sans-serif', padding: '2rem', background: '#0d1117', color: '#e6edf3', minHeight: '100vh' }}>
      <h1 style={{ color: '#3fb950' }}>My App</h1>
      <p style={{ color: '#8b949e' }}>Deployed via platform-one · Status: <strong style={{ color: status === 'connected' ? '#3fb950' : '#f85149' }}>{status}</strong></p>
      <p style={{ color: '#8b949e', marginTop: '1rem' }}>
        Replace this with your application code. This scaffold is already wired to:<br/>
        ArgoCD auto-sync · OTel sidecar · Prometheus metrics · Kyverno policies
      </p>
    </div>
  )
}
