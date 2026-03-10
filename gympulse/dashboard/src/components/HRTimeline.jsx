import React from 'react';
import {
  AreaChart, Area, XAxis, YAxis, ReferenceLine, ReferenceArea,
  ResponsiveContainer, Tooltip,
} from 'recharts';
import { formatTime } from '../utils/formatters';

export default function HRTimeline({ history, sets }) {
  const data = history.map((d, i) => ({
    idx: i,
    hr: d.hr,
    time: formatTime(d.et),
    state: d.state,
  }));

  // Build set/rest regions for shading
  const setRegions = [];
  const restRegions = [];

  if (data.length > 0) {
    let regionStart = null;
    let regionState = null;

    for (let i = 0; i < data.length; i++) {
      const s = data[i].state;
      if (s !== regionState) {
        if (regionState === 'ACTIVE_SET' && regionStart !== null) {
          setRegions.push({ x1: regionStart, x2: i - 1 });
        } else if (regionState === 'RESTING' && regionStart !== null) {
          restRegions.push({ x1: regionStart, x2: i - 1 });
        }
        regionStart = i;
        regionState = s;
      }
    }
    // Close last region
    if (regionState === 'ACTIVE_SET' && regionStart !== null) {
      setRegions.push({ x1: regionStart, x2: data.length - 1 });
    } else if (regionState === 'RESTING' && regionStart !== null) {
      restRegions.push({ x1: regionStart, x2: data.length - 1 });
    }
  }

  // Set boundary reference lines
  const setLines = sets.map((s) => {
    const matchIdx = history.findIndex((d) => d.et >= s.end_time);
    return matchIdx >= 0 ? matchIdx : null;
  }).filter(Boolean);

  return (
    <>
      <div className="card-title">HR Timeline</div>
      <div className="timeline-container">
        <div className="timeline-chart">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
              <defs>
                <linearGradient id="hrGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#ef5350" stopOpacity={0.2} />
                  <stop offset="95%" stopColor="#ef5350" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis
                dataKey="time"
                tick={{ fontSize: 10, fill: '#3e4859' }}
                tickLine={false}
                axisLine={false}
                interval="preserveStartEnd"
              />
              <YAxis
                domain={[40, 200]}
                tick={{ fontSize: 10, fill: '#3e4859' }}
                tickLine={false}
                axisLine={false}
                tickCount={5}
              />
              <Tooltip
                contentStyle={{
                  background: '#1a1f2a',
                  border: '1px solid #2a2a35',
                  borderRadius: 6,
                  fontSize: '0.75rem',
                }}
                labelStyle={{ color: '#8892a4' }}
              />
              {/* Set regions (orange tint) */}
              {setRegions.map((r, i) => (
                <ReferenceArea
                  key={`set-${i}`}
                  x1={data[r.x1]?.time}
                  x2={data[r.x2]?.time}
                  fill="#ff9800"
                  fillOpacity={0.06}
                />
              ))}
              {/* Rest regions (blue tint) */}
              {restRegions.map((r, i) => (
                <ReferenceArea
                  key={`rest-${i}`}
                  x1={data[r.x1]?.time}
                  x2={data[r.x2]?.time}
                  fill="#2196f3"
                  fillOpacity={0.04}
                />
              ))}
              <Area
                type="monotone"
                dataKey="hr"
                stroke="#ef5350"
                fill="url(#hrGrad)"
                strokeWidth={2}
                dot={false}
                isAnimationActive={false}
              />
              {setLines.map((idx, i) => (
                <ReferenceLine
                  key={i}
                  x={data[idx]?.time}
                  stroke="#e040fb"
                  strokeWidth={1}
                  strokeDasharray="4 4"
                  opacity={0.5}
                />
              ))}
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>
    </>
  );
}
