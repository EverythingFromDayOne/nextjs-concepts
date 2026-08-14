'use client'

// error.tsx must be a Client Component — it needs an error boundary, which
// only exists on the client. Experiment B confirms whether the framework
// enforces this or merely documents it.
export default function ConventionsError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div data-marker="error">
      <p>error: {error.message}</p>
      <button onClick={reset}>reset</button>
    </div>
  )
}
