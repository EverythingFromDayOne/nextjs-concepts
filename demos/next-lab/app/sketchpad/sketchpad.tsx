'use client'

// client: pointer events at ~60Hz and a mutable canvas ref. Neither has a
// server representation, and neither would survive a round trip.
import { useEffect, useRef, useState } from 'react'

export function Sketchpad() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [drawing, setDrawing] = useState(false)
  const [strokes, setStrokes] = useState(0)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    // Device pixel ratio is a browser fact. There is no server answer.
    const dpr = window.devicePixelRatio ?? 1
    canvas.width = canvas.clientWidth * dpr
    canvas.height = canvas.clientHeight * dpr
    canvas.getContext('2d')?.scale(dpr, dpr)
  }, [])

  function draw(e: React.PointerEvent<HTMLCanvasElement>) {
    if (!drawing) return
    const ctx = canvasRef.current?.getContext('2d')
    if (!ctx) return
    const rect = canvasRef.current!.getBoundingClientRect()
    ctx.lineTo(e.clientX - rect.left, e.clientY - rect.top)
    ctx.stroke()
  }

  return (
    <div>
      <canvas
        ref={canvasRef}
        style={{ width: '100%', height: 300, border: '1px solid #ccc' }}
        onPointerDown={(e) => {
          setDrawing(true)
          setStrokes((s) => s + 1)
          const ctx = canvasRef.current?.getContext('2d')
          const rect = canvasRef.current!.getBoundingClientRect()
          ctx?.beginPath()
          ctx?.moveTo(e.clientX - rect.left, e.clientY - rect.top)
        }}
        onPointerMove={draw}
        onPointerUp={() => setDrawing(false)}
      />
      <p>{strokes} strokes</p>
    </div>
  )
}
